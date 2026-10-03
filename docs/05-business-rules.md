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
If an educational-policy setting is still unconfigured, the backend must reject or hold only operations that require that setting. For example, an official Blitz cannot be activated without a timer-start mode; an open official Topic result whose Homework and Blitz scores are both ready stays in status **Waiting for settings** until the Institution has both an acceptable-difference threshold and a valid complete understanding-category configuration (BR-STAT-007A); while the Student result-release mode is unconfigured, no Topic result becomes visible through the mode and a Teacher release returns `409 manual_release_not_allowed` (releases already made stay, BR-STAT-017A); and while the Parent result-visibility mode is unconfigured, Parents receive no result information, as in **Hidden** mode (BR-STAT-014). General user/group administration and unrelated draft authoring remain available.

**BR-INST-017 — Setting isolation**  
Changing one institution’s settings must not affect another institution.

**BR-INST-018 — Open results use current settings; closed results keep theirs**
An open (not closed) Topic result keeps no copy of the institution rules: it always uses the Institution's current acceptable-difference threshold and current category ranges (`S10-D6`). Closing a result stores the threshold, category, and category range it used in the closure snapshot (BR-RES-011A); a closed result never reads current settings again. Changing category ranges or the acceptable score difference therefore changes every open result on its next read and never rewrites a closed result.

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
A Student may access only assigned topics, materials, homework, active blitz tasks, own finished (closed or archived) Blitz tasks, own submissions, own Attempt results and Teacher answer feedback only when visible under BR-STAT-020 to BR-STAT-023, own Topic result statuses, own Topic result values (scores, calculation method, understanding category, and the Teacher's Topic-result comment) only when visible under BR-STAT-013 to BR-STAT-013B, and own progress. A Student never sees correct answers, answer keys, per-Question awarded points, per-answer checking status, reviewer identity, the Homework review deadline, or a Topic result's score difference, threshold, consistency, or `category_score` (`S10-D2`).

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
The official result-bearing pair uses one common Student cohort. The first activated official whole-group task establishes the common official Student cohort from its persisted recipient snapshot. If the official Homework is the first task, Stage 6 stores that cohort without fabricating a Blitz or Blitz recipient rows. When the official Blitz is later designated or activated, it must use exactly the same cohort. Later Group membership changes do not rewrite the official cohort. Since Stage 10 the official Blitz cannot activate while the official Homework is a draft (BR-BLZ-010A). In history from before Stage 10, if the official Blitz activated first while `cohort_snapshotted_at = null`, its persisted whole-group recipient snapshot established the cohort at that activation instant; the official Homework ID is preserved and no Homework Attempt is created, and a later official Homework activation reuses that cohort. Account-active/security checks still apply to historical recipients.

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
Closing a topic must block new homework or blitz submissions when the connected task rules no longer permit them. Existing submissions may still be reviewed. A topic cannot be closed or archived while any of its Homework is draft or active, or any of its Blitz is draft, scheduled or active; the request returns `409 topic_has_open_assessments` and changes nothing. Closing a topic closes no Topic result.

**BR-TOP-010 — Archiving a topic**  
Archiving must preserve materials, tasks, submissions, results, and reports as read-only historical information for authorized users. Stage 9 automatic checking of frozen Attempts and Teacher review and correction of existing submissions remain allowed (BR-Q-037), except a correction for a Student whose Topic result is closed (BR-RES-011B). Inside the archive transaction, archiving also closes every terminal Topic result of the official cohort (open **Calculated** or open **Not completed**, BR-STAT-010B) with closure reason `topic_archived`, recorded as closed by the archiving Teacher; results that still wait stay open (`S10-D7`, BR-RES-011). The archive request, response, and conflicts are unchanged. This is a deliberate Stage 10 change to the Stage 5 archive behavior.

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

**BR-HW-005A — First official Homework activity locks pair meaning**
Creating the first Attempt for the official Homework must, in the same transaction, resolve and lock the result pair in the same Institution/Topic, require a persisted cohort snapshot and the Student's membership in that official cohort, and set a null pair `locked_at` plus `updated_at` to the same `startedAt` used for the Attempt. An existing `locked_at` must be preserved. `blitz_assessment_id` may remain null; the flow must never replace official Homework/cohort identity or create a Blitz. Structural pair/cohort inconsistency fails atomically without repair/resnapshot, and practice Homework must not mutate the result pair.

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
Closing Homework blocks new Starts and Student answer/file/Submit writes. Before the deadline, the backend captures one `closedAt = server_now` and atomically closes the Homework and freezes every still-`in_progress` Attempt as `status = submitted`, `submitted_at = null`, `finalized_at = locked_at = closedAt`, and `finalization_reason = task_closed_auto_finalize`; all changes commit or roll back together. Finalization preserves only already-committed Student answers/files as pending, performs no Stage 7 checking/scoring, and creates neither an Attempt for a never-started Student nor an answer row for an unanswered Question. At or after the deadline, close must reconcile the deadline first and preserve `homework_deadline_auto_submit` plus the exact deadline timestamp. Repeated close/finalization must not rewrite an already-frozen reason or timestamp. Stage 9 may later check the frozen work and apply the approved missing-answer-zero policy. A Homework close records no actor. Besides a Teacher close, an active official Homework is also closed in exactly this way by the activation of the official Blitz, inside the activation transaction (Homework before Blitz, BR-BLZ-010A, `S10-D8`).

**BR-HW-013 — Archived homework**  
Archived homework must be retained for history and reports and must not accept new activity. Stage 9 automatic checking of its frozen Attempts and Teacher review and correction of its existing submissions remain allowed (BR-Q-037), except a correction for a Student whose Topic result is closed (BR-RES-011B); only its review deadline can no longer change (BR-HW-018A).

### Deadlines

**BR-HW-014 — Optional deadline**  
A Teacher may define a homework deadline.

**BR-HW-015 — Deadline visibility**  
The Student must see the deadline before starting the homework.

**BR-HW-016 — Deadline auto-finalization**  
When `server_now >= deadline_at`, the authoritative Homework deadline reconciliation must block new Starts and Student answer/file/Submit writes and freeze every existing `in_progress` Homework Attempt using only work already committed before finalization. The frozen state is `status = submitted`, `submitted_at = null`, `finalized_at = locked_at = deadline_at`, and `finalization_reason = homework_deadline_auto_submit`; delayed processing must not replace the exact historical deadline instant. Saved answers remain pending with no Stage 7 checking, awarded points, review metadata, or payload/file rewrite. A never-saved Question requires no fabricated answer row, a never-started Student receives no fabricated Attempt, and unused attempt capacity becomes unavailable. Stage 9 later checks the frozen work, treats missing answers as zero under the approved policy, and performs official-score selection. Advanced late-submission penalties and post-deadline completion workflows are outside the MVP.

**BR-HW-017 — Deadline boundary and late requests**  
A Homework Start or Student answer/file/Submit mutation may continue only when the post-lock authoritative check has `server_now < deadline_at`. Relevant Student Homework/Attempt reads, Start, answer/file mutation, Submit, Teacher close when the deadline may have passed, and the Scheduler must reuse one behavior such as `FinalizeHomeworkAttemptsAtDeadline`; Scheduler latency never extends eligibility. Submit, deadline reconciliation, and Teacher close serialize through deterministic locks and produce exactly one transition from `in_progress`, preserving the first committed reason/timestamps. Answer/file mutation uses the same Homework/Attempt lock boundary and re-checks lifecycle, authoritative time, and editability: a mutation committed first is part of the frozen Attempt; finalization committed first causes zero answer/file-domain mutation and the documented conflict. No Student write may commit after freeze.

**BR-HW-018 — Authoritative time and institution timezone**  
Deadline validation must use backend-authoritative time. Authoritative timestamps must be stored as UTC instants. Teachers enter educational dates and times in the institution’s configured IANA timezone, and educational schedules are displayed in that institution timezone. A device clock or device timezone must not change the actual deadline. Changing an institution timezone later must not change the absolute instant of an already-created deadline.

**BR-HW-018A — Homework review deadline is a reminder only**
A Teacher may give a Homework an optional review deadline (`review_due_at`, “check by”). It is entered like `deadline_at`, in Institution time; it may be cleared, may lie in the past, and has no ordering rule against `deadline_at`. It is not a fairness field, so existing Attempts never block changing it. The Teacher may set, change, or clear it while editing a draft or active Homework and also after the Homework is closed, because review usually happens after closing; an archived Homework, or a Homework whose Topic is closed or archived, cannot change it. The review deadline is a reminder only: it never changes scores, checking statuses, or official-score selection. A submission is overdue when it is waiting for Teacher review and the Homework review deadline is set and not later than server now. Blitz has no review deadline. Students never see the review deadline.

### Homework Editing and Integrity

**BR-HW-019 — Pre-attempt editing**  
The Teacher may edit homework content while it is draft and no student attempt has started.

**BR-HW-020 — Lock scoring content after first attempt**  
After any student begins an attempt, the Teacher must not change questions, answer options, correct answers, points, task recipients, or other scoring-relevant rules for that active assignment.

**BR-HW-021 — Safe metadata changes**  
Non-scoring metadata may be corrected only when it does not change the meaning or fairness of existing student work.

**BR-HW-021A — No hard deletion after activity**
Homework with attempts, submissions, scores, or results must not be permanently deleted. It must be closed or archived.

### Homework Scoring and Visibility

The rules in this subsection are Stage 9 behavior. Stage 7 only freezes Student work as immutable `submitted` history and does not check answers, award points, create Teacher-review metadata, or select an official Homework score.

**BR-HW-022 — Automatic and manual scoring**  
Automatically checked Questions are scored by the system under the Section 8 rules right after the Attempt is frozen (BR-Q-034). Answered manual Questions worth more than zero points wait for Teacher review (BR-Q-038).

**BR-HW-023 — Homework score readiness**  
Each completed Homework attempt receives its normalized score only when it becomes `checked`, after all required automatic and manual checking for that attempt is complete (BR-Q-033). The official Homework score is the highest checked eligible score among the Student’s Attempts and becomes ready only when no pending Attempt could still overtake it (BR-ATT-019).

**BR-HW-024 — Homework is not the final topic result**  
A final homework score must remain separate from the final topic result until the blitz score is available and comparison rules are applied.

**BR-HW-025 — Parent access**  
A Parent sees a connected child’s official Homework through the child’s Topic result (BR-STAT-016A): unless the Parent mode is hidden or unconfigured, the Parent sees the result status, including a missing Homework, and, when the result values are visible to the Parent, the official Homework score together with the Teacher’s Topic-result comment. Teacher feedback on answers is Student-only and is never visible to a Parent (`S10-D1`). A Parent must not view or edit protected answer content unless separately allowed.

**BR-HW-026 — Student view of Homework results**
A Student sees own Homework Attempt results, Teacher feedback on own answers, and the official Homework score only under BR-STAT-020 and BR-STAT-021. The Homework review deadline is never shown to the Student.

---

## 8. Assignment Type and Checking Rules

For Homework, this section's checking, awarded-points, review, and score-completion rules are Stage 9 behavior applied to immutable Stage 7 `submitted` history. Stage 7 may validate and persist each answer type but leaves saved answers pending and does not execute these checking rules. For Blitz, Stage 8 likewise freezes committed work as immutable execution history with saved answers pending; Stage 9 owns checking, Teacher review, awarded points, Attempt scoring, and official task-score selection. Stage 10 owns Homework–Blitz comparison, final Topic results, categories, and release.

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

**BR-Q-005A — Teacher text is never blank (`CL9-11`)**
A Teacher text value that is blank after trimming the Student-answer whitespace set of BR-Q-013A (U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF) is rejected with the error the request already returns for an ASCII-blank value. This applies to the Question prompt, the choice option texts, the short-written accepted answers, the matching left and right texts, the ordering item texts, the fill-in-the-blank accepted answers, the Homework and Blitz title and Student instructions, and the Blitz exception reason (BR-ATT-014). Stored values are never rewritten, and answer-feedback trimming (BR-Q-038) is unchanged.

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
awarded_points = question_points × correctly_selected_options / total_correct_options
```

The formula is computed in one step and stored under BR-Q-036. Incorrectly selected options receive no credit and do not create an additional negative penalty. An unanswered Question receives zero (BR-Q-030). Flutter enforces the selection cap for UX, and the backend enforces it authoritatively when the answer is saved.

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

Short written answer is the only Question type whose checking can be switched to manual. Open written and file-based Questions are always checked manually; all other types are always checked automatically.

**BR-Q-013 — Accepted-answer requirement and short-answer scoring**  
If automatic checking is enabled, the Teacher must define at least one accepted answer. An automatically checked short written answer is all-or-nothing: a value whose normalized form (BR-Q-013A) equals the normalized form of any accepted answer earns the full points, and a non-matching or unanswered value earns zero. If manual checking is used, the Teacher may award any valid score from zero to the question’s maximum points.

**BR-Q-013A — Automatic text normalization**
For automatic Short Written checking and for Fill-in-the-Blank blanks (BR-Q-024), the Student answer and every Teacher-defined accepted answer must pass the same deterministic normalization, in this order, before comparison:

1. Unicode NFC normalization.
2. Unicode full case folding (locale-independent).
3. Unicode NFC normalization again.
4. Map the apostrophe variants U+0027 `'`, U+0060 `` ` ``, U+00B4 `´`, U+02BB `ʻ`, U+02BC `ʼ`, U+2018 `‘`, and U+2019 `’` to U+0027.
5. Replace every run of Student-answer whitespace (U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF) with one U+0020.
6. Trim leading and trailing spaces.

The normalized values are then compared exactly. Punctuation and other symbols remain significant. The MVP must not use fuzzy matching, spell correction, synonym inference, or AI interpretation. If flexible judgment is needed, a manually checked Question must be used.

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
The system must check matching tasks automatically where the mapping is objective. Each correctly matched pair earns an equal share of the question’s points: `awarded_points = question_points × correct_pairs / total_left_items`, computed in one step (BR-Q-036). A pair is correct when the chosen right item carries the left item’s match key. Incorrect or missing pairs earn zero for that pair. No negative points are awarded.

### Ordering Task

**BR-Q-021 — Ordering structure**  
An ordering task must contain two or more items and one defined correct order.

**BR-Q-022 — Ordering partial-credit checking**  
The system must check ordering tasks automatically. Each item placed in its exact correct position earns an equal share of the question’s points: `awarded_points = question_points × correctly_positioned_items / total_items`, computed in one step (BR-Q-036). An item counts only at its exact correct position; positions are 1-based on both the Student and the Teacher side. An item in the wrong position earns zero for that item. No negative points are awarded.

### Fill-in-the-Blank

**BR-Q-023 — Blank structure**  
Each blank must have one or more Teacher-defined accepted values.

**BR-Q-024 — Fill-in-the-blank partial-credit checking**  
The system must check each objective blank automatically according to the accepted-answer rules. A blank is correct when its normalized value equals the normalized value of any accepted answer of that blank, using the same normalization as short answers (BR-Q-013A). Each correctly completed blank earns an equal share of the question’s points: `awarded_points = question_points × correct_blanks / total_blanks`, computed in one step (BR-Q-036). An incorrect or unanswered blank earns zero for that blank. No negative points are awarded.

### Checking Completion

**BR-Q-025 — Automatic score timing**  
When Stage 9 checks a frozen submission and the automatic run leaves no answer waiting for Teacher review (the submission has no answered manual Question worth more than zero points), the Attempt becomes **Checked** and its score is calculated without Teacher review (BR-Q-033). Stage 7 Homework and Stage 8 Blitz finalization do not perform that checking/scoring.

**BR-Q-026 — Manual-review status**  
When at least one answered manual Question is worth more than zero points, that answer and the submission enter **Waiting for teacher review** (BR-Q-033).

**BR-Q-027 — Final task score**  
A task score must not be treated as final until all required questions have a score.

**BR-Q-028 — Teacher answer boundary**  
The Teacher may score and comment on a Student’s answer but must not rewrite the Student’s submitted answer.

**BR-Q-029 — AI exclusion**  
AI-generated checking, AI-generated scoring, and AI-generated feedback are outside the MVP.

### Stage 9 Automatic Checking

**BR-Q-030 — Unanswered Questions**
An unanswered Question (no saved answer) contributes zero points. No answer is fabricated for it and it requires no Teacher review, also when it is a manual Question. An empty saved answer cannot exist, because clearing an answer deletes it.

**BR-Q-031 — Zero-point Questions**
An automatically checked answer to a zero-point Question is checked with zero points. A manual answer to a zero-point Question is closed automatically as `auto_checked` with zero points and never enters Teacher review.

**BR-Q-032 — Automatic result record**
An automatically checked answer records the checking time as `checked_at` and leaves `checked_by_user_id` empty.

**BR-Q-033 — Checking states**
An answer’s `checking_status` changes only as follows:

```text
pending → auto_checked                          (automatic Questions; zero-point manual answers)
pending → waiting_for_teacher_review            (manual answer worth more than zero points)
waiting_for_teacher_review → teacher_checked    (Teacher review)
teacher_checked → teacher_checked               (Teacher correction)
```

An Attempt’s `status` changes only as follows:

```text
submitted | timed_out_finalized
  → checked                                    (the automatic run leaves no waiting answer)
  → waiting_for_teacher_review                 (at least one waiting answer)
waiting_for_teacher_review → checked           (the last waiting answer is reviewed)
checked → checked                              (a correction recalculates the score)
```

When an Attempt becomes `checked`, and after every correction, its earned points, normalized score, and scoring-completion time (the time of the latest scoring) are set. While the Attempt waits for Teacher review, its earned points and normalized score stay empty. Checking never changes `finalization_reason`, `submitted_at`, `finalized_at`, or `locked_at`.

**BR-Q-034 — When automatic checking runs**
The freeze itself performs no checking; Stage 9 checks each frozen Attempt right after the transaction that froze it commits. The freezing points are Homework Submit, Homework deadline reconciliation, and Homework close (by the Teacher or by the official Blitz activation, BR-BLZ-010A); Blitz Submit, Blitz timeout reconciliation, Blitz Teacher close, and the timeout finalization performed during a Blitz exception grant. Each Attempt is checked on its own; a checking failure is logged and never undoes or alters the freeze or changes the freeze response. A sweep that runs every minute checks every Attempt still in `submitted` or `timed_out_finalized`, including history frozen before Stage 9, and repairs the stored official score of a Student who has a `checked` eligible Attempt and no pending eligible Attempt when that score is missing or differs from its live evaluation (BR-ATT-021). Checking acts only on Attempts still in `submitted` or `timed_out_finalized`, so repeating it changes nothing.

**BR-Q-035 — Invalidated Blitz attempts and practice tasks**
An invalidated Blitz Attempt #1 is checked like any Attempt and may wait for Teacher review; it is never official and never blocks the official Blitz score. The Student-facing status **Invalidated by approved exception** is derived, not stored (BR-STAT-004A). Practice (non-official) Homework and Blitz tasks are checked and reviewed like official tasks but never receive an official score.

### Attempt Scoring and Precision

**BR-Q-036 — Exact scoring arithmetic**
Scoring never uses binary floating point; every scoring calculation uses exact decimal arithmetic:

- A partial-credit Question is computed in one step, `question_points × correct / total`, and its awarded points are stored rounded half-up to 8 decimal places. A fully correct answer always stores exactly the Question points, so earned points never exceed possible points.
- An Attempt’s earned points are the exact sum of its answers’ stored awarded points.
- The normalized score is `earned_points × 100 / possible_points`, rounded half-up to 8 decimal places. Possible points are the snapshot taken when the Attempt started and are always positive.
- Official selection, ties, and every later comparison use the stored normalized scores; any bound compared with them (BR-ATT-019) is rounded the same way first.
- Scores are displayed with one decimal place using standard half-up rounding. Clients never calculate with scores received from the API.
- Teacher-awarded points follow the Question points number rule: at most 6 fractional digits.

### Teacher Review and Correction

**BR-Q-037 — Teacher review access**
A submission is a terminal Attempt (`submitted`, `timed_out_finalized`, `waiting_for_teacher_review`, or `checked`) of a Homework or Blitz. A Teacher may open a submission only when the Topic is visible to that Teacher (same Institution, the Teacher owns the Topic, and the Teacher is currently a member of its Group) and the Student is a persisted recipient of the task. Anything else, including an `in_progress` Attempt, is a privacy-safe not-found response. Topic, Homework, and Blitz status (active, closed, or archived) does not restrict review; a closed Topic result blocks only corrections (BR-Q-039). The Teacher sees every Question of the task in position order with its correct-answer configuration, and the Student’s answer with its checking state, awarded points, feedback, and last reviewer; an unanswered Question shows no answer. The Teacher may download the submitted answer files of an accessible submission (BR-SUB-016). By default the review queue orders official-task submissions before practice ones, then overdue submissions (BR-HW-018A) before the rest, then the earliest finalized first; an invalidated Blitz Attempt #1 is listed with practice work and labeled invalidated. Review is desktop-only in the Teacher interface; on mobile the Teacher sees only each task’s counts of submissions waiting for review and, for a Homework, overdue. The server does not check the device (BR-ROLE-023).

**BR-Q-038 — Teacher review of manual answers**
The Teacher reviews only manual-review answers of an accessible submission (answers in `waiting_for_teacher_review` or `teacher_checked`); automatically checked answers and the Student’s answer content cannot be changed (BR-Q-028). For each reviewed answer the Teacher awards points from 0 to the Question’s points under the number rule of BR-Q-036 and gives feedback or none. Feedback is trimmed of ASCII whitespace (space, tab, CR, LF, NUL, vertical tab), empty feedback means none, it holds at most 2000 characters, and giving none clears earlier feedback. A review may save any subset of the manual answers (partial review). A submission still awaiting automatic checking (`submitted` or `timed_out_finalized`) cannot be reviewed and returns `409 automatic_checking_pending`. Saving marks each reviewed answer `teacher_checked` with the reviewer and the server time, recalculates the Attempt (BR-Q-033), and re-resolves the official score (BR-ATT-021), all in one transaction. Concurrent reviews of one submission apply one after another, and each answer keeps the last committed value.

**BR-Q-039 — Teacher correction**
A Teacher corrects an already reviewed (`teacher_checked`) answer in the same way. The Attempt stays `checked` and is recalculated; the official score is re-resolved and may move to another Attempt. Stage 10 adds the closure guard (BR-RES-011B, `S10-T7`): when the Student’s Topic result is closed, a review request on an Attempt of the Topic’s official Homework or official Blitz that names any `teacher_checked` answer (a correction) fails as a whole with `409 result_closed` and changes nothing; this check runs inside the scoring-lock transaction, after the re-checked `409 automatic_checking_pending` check and before the item re-validation and any write, while invalid items still get the existing pre-transaction `422` first. A first review of a still-waiting answer stays allowed after closure, and practice tasks are never affected.

**BR-Q-040 — Review record and feedback location**
Each answer keeps only its last reviewer (`checked_by_user_id`) and review time (`checked_at`); there is no review history. Teacher feedback on answers stays on answers and is Student-only. Stage 10 adds one optional Teacher comment on the Topic result (BR-RES-007A); there is no Parent-visible feedback flag (`S10-D1`).

---

## 9. Attempt Rules

### Fixed MVP Attempt Model

**BR-ATT-001 — Homework has three normal attempts**  
Every Homework assignment in the MVP must allow a Student up to **three normal attempts**. Institution Admins and Teachers must not increase or decrease this normal Homework attempt count in the MVP.

**BR-ATT-002 — Homework official score uses the highest valid completed attempt**  
The official Homework score is the highest normalized score among the Student’s valid completed and fully checked Homework attempts. A Student does not need to use all three attempts. If only one or two valid completed attempts exist, the highest score among those completed attempts becomes the official Homework score. The official score waits only for an Attempt that could still overtake it (BR-ATT-019).

**BR-ATT-003 — No fourth normal Homework attempt**  
After the Student has used three normal Homework attempts, the system must block a fourth normal attempt. The approved MVP does not include a Teacher-granted extra Homework attempt.

**BR-ATT-003A — One current Homework Attempt and Start/resume**
For one Student/Homework, at most one Attempt may have `status = in_progress`. A valid Start returns/resumes that existing Attempt without consuming capacity; otherwise it allocates `max(existing attempt_number) + 1`, up to 3, under application locking and database enforcement. Concurrent same-key or different-key Starts must still create at most one logical/current Attempt, must not duplicate or skip an attempt number because of a race, and a Start after Attempts 1, 2, and 3 exist is rejected as exhausted.

**BR-ATT-004 — Blitz has one normal attempt**  
Every Blitz task in the MVP must allow **one normal attempt** per assigned Student.

**BR-ATT-004A — Explicit Blitz Start intents and exact results**
`POST /api/v1/student/blitz/{blitz}/attempts` requires `Idempotency-Key`, no query parameters, and exactly one of these bodies:

- `{"intent":"start_normal"}`
- `{"intent":"resume","attempt_id":"attempt-uuid"}`
- `{"intent":"start_replacement"}`

Resume requires a canonical UUID for the exact own Attempt; both Start intents forbid `attempt_id`. Missing/empty/`{}`/non-object/malformed bodies, unknown keys/intents, and missing/malformed/non-canonical Resume IDs return `422 validation_failed` before business execution. Authorization, lifecycle, and applicable timing requirements remain mandatory. For fresh requests:

| Intent and current state | Exact result |
|---|---|
| `start_normal`: no #1, all preconditions pass | Create normal #1; `201`. |
| `start_normal` on the official Blitz: no #1, the existing executability checks pass, and the Student has no terminal Attempt of the official Homework | `409 homework_not_submitted`. No Attempt (BR-BLZ-011A). |
| `start_normal`: own editable `in_progress` #1 | Return same #1; `200`, without timer reset. |
| `start_normal`: due `in_progress` #1 | Authoritative timeout reconciliation when the owning finalization contract is available, then `409 blitz_time_expired`. |
| `start_normal`: terminal #1 with `finalization_reason = timeout_auto_submit` (whatever its later checking status) and no approved exception | `409 blitz_time_expired`. No new Attempt. |
| `start_normal`: otherwise terminal #1, or an approved exception exists | `409 attempts_exhausted`, even if replacement capacity exists. |
| `resume`: exact own editable `in_progress` target | Return only that target; `200`. |
| `resume`: exact own due `in_progress` target | Canonically reconcile timeout, then `409 blitz_time_expired`. |
| `resume`: exact own target is terminal with `finalization_reason = timeout_auto_submit` (whatever its later checking status) | `409 blitz_time_expired`. |
| `resume`: otherwise terminal exact own target (any other finalization reason), including valid later checking history | `409 attempt_not_editable`. |
| `resume`: another Student/Blitz/Institution or otherwise out-of-scope target | Privacy-safe `404 resource_not_found`. |
| `start_replacement`: valid unused approved capacity and all preconditions pass | Create #2; `201`. |
| `start_replacement`: own editable `in_progress` #2 | Return same #2; `200`, without timer reset. |
| `start_replacement`: due `in_progress` #2 | Canonically reconcile timeout, then `409 blitz_time_expired`. |
| `start_replacement`: #2 is terminal with `finalization_reason = timeout_auto_submit` (whatever its later checking status) | `409 blitz_time_expired`. |
| `start_replacement`: consumed, otherwise terminal #2, or otherwise structurally valid history with no approved exception/available capacity | `409 attempts_exhausted`. |
| `start_replacement`: existing invalid exception graph/capacity | `409 blitz_attempt_exception_not_allowed`, preserving the invariant/public-error split. |

A selected terminal Attempt with `finalization_reason = timeout_auto_submit` answers `409 blitz_time_expired` whatever its later checking status (`timed_out_finalized`, `waiting_for_teacher_review`, or `checked`), whether the Scheduler or the request path finalized it; the only exception is `start_normal` when an approved exception exists. Amended 2026-09-28 (`S08-CLOSURE-FIX-001`) to match `docs/09-api-contracts.md` §20.3 (owner decision D3, `S08-BE-PHASE-2-FIX-002`). Rekeyed for Stage 9 (`S09-DOC-001`, `S09-T2`) from the status `timed_out_finalized` to the finalization reason, so the observable responses stay exactly as in Stage 8 after Stage 9 checking changes the status. Amended 2026-10-03 (`S10-DOC-001`, `S10-D8`) with the `homework_not_submitted` row only; every other row is unchanged.

`start_normal` never creates #2. Resume never creates, switches, or selects a newer Attempt. Only `start_replacement` creates #2; #3 is forbidden. Existing `started_at`, `deadline_at`, and `attempt_number` never change on a returned Attempt.

All intents use `student.blitz.attempt.start`; the fingerprint contains the authorized lowercase Blitz UUID, exact `intent`, and lowercase validated `attempt_id` only for Resume, never derived timer/lifecycle/capacity state. After authorization, completed valid same-key/same-fingerprint replay precedes the fresh matrix, returns the same logical result, preserves original `201` for creation or `200` for returning an existing Attempt, and creates no new Attempt or timer/history mutation. Later lifecycle changes never reinterpret the intent. A different Blitz, intent, or Resume target under the same key returns `409 idempotency_key_reused`; replacement Start requires its own new logical request/key.

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
A Student must not start or submit a new Homework attempt after the Homework deadline. A Student must not start a Blitz attempt unless the Blitz is active and the applicable timing rules allow it. A Student must not start normal Attempt #1 of the official Blitz without a submitted Attempt of the official Homework (BR-BLZ-011A, `S10-D8`).

**BR-ATT-013 — Assignment required**  
A Student must not use an attempt for a task that is not assigned to that Student.

### Technical Problems and Blitz Exceptions

**BR-ATT-014 — Valid exception reasons**  
A Blitz exception may be granted only for a technical problem or another valid reason that prevented the Student from completing the normal Blitz attempt fairly. The exception is not a normal retry for improving a low valid score.

**BR-ATT-015 — Teacher approval and reason required**  
Only an authorized Teacher for the Student’s group/topic may approve the additional Blitz attempt. The Teacher must record a reason for the exception.

A new grant requires the same Institution, persisted Blitz recipient, existing normal Attempt #1, no previous exception, no #2, and exactly `BlitzTask.status = active`. Draft, scheduled, closed, or archived grants return `409 blitz_attempt_exception_not_allowed`. Teacher Close permanently prevents new grants and an exception never reopens the Blitz. An elapsed `synchronized_ends_at` alone does not block an otherwise valid grant while active. Missing #1 returns `409 blitz_normal_attempt_required`; an existing exception returns `409 blitz_attempt_exception_already_granted`.

Locked authoritative state governs #1: a pre-deadline editable #1 returns `409 blitz_attempt_exception_not_allowed` with no exception, eligibility mutation, #2, or synthetic finalization. A due `in_progress` #1 is first timeout-finalized at its exact deadline; only if all other grant preconditions pass does the atomic workflow record the exception and exclusion. Already-terminal #1 retains its reason/timestamps. No two Blitz Attempts may be simultaneously `in_progress`.

**BR-ATT-016 — Invalidated Blitz attempt remains in history**  
Successful exception grant creates one durable `blitz_attempt_exceptions` record, preserves normal Attempt #1 and its answers/files, and sets `official_score_eligible = false` on #1. It authorizes exactly replacement #2 without creating it (`replacement_attempt_id = null` at grant). No new finalization reason is invented and the class-wide normal attempt count remains one.

**BR-ATT-017 — Additional Blitz attempt becomes the score source**  
When an approved exception invalidates the normal Blitz attempt, Stage 9 selects the valid completed replacement #2 once #2 is `checked` (BR-ATT-020). In both timer modes #2 receives `deadline_at = started_at + duration_seconds` from its own canonical server Start. It uses the existing full configured duration and never changes activation, `timer_start_mode_snapshot`, `synchronized_ends_at`, or another Student's deadline. It may start after the common synchronized end while the Blitz remains active and all replacement preconditions pass.

### Official Score Selection

**BR-ATT-018 — Exactly one official task score**  
Before Homework–Blitz comparison, the system must identify exactly one official Homework score and exactly one official Blitz score for the Student and topic. Stage 9 selects official task scores automatically and keeps them only for the Homework and the Blitz of the Topic result pair; a Teacher never chooses the official Attempt. Practice tasks and an invalidated Blitz Attempt #1 never provide an official score. A Student has an official score for a task exactly while that score is ready under BR-ATT-019 or BR-ATT-020.

**BR-ATT-019 — Homework selection policy is highest valid score**  
The official Homework score must be selected automatically as the highest normalized score among up to three valid completed Homework attempts, and it waits only for an Attempt that could still overtake it. Eligible Attempts are the Student’s Attempts of the official Homework with `official_score_eligible = true`; `in_progress` Attempts are not considered.

1. `best` is the `checked` eligible Attempt with the highest normalized score. If multiple eligible attempts have exactly the same highest normalized score, the earliest such attempt — the one with the lowest `attempt_number` — is `best`; the numeric official score remains the shared highest score. With no `checked` eligible Attempt, the official score is not ready.
2. Every eligible terminal Attempt that is not `checked` is **pending**. Its upper bound is `(awarded points of its checked answers + full points of its waiting answers) × 100 / possible_points`, rounded as in BR-Q-036; an Attempt not yet automatically checked has upper bound 100.
3. The official score is not ready while any pending Attempt has an upper bound greater than `best`, or equal to `best` with a lower `attempt_number` than `best`.
4. Otherwise `best` becomes `official_attempt_id`, with selection policy `highest_valid_completed`.

When a later Attempt becomes pending and could overtake, a ready official score becomes not ready until that Attempt is checked; this is intended.

**BR-ATT-020 — Blitz selection policy is the valid allowed attempt**  
Normally, the Student’s single valid completed Blitz attempt is the official Blitz score. If that normal attempt is invalidated through an approved exception, the valid completed additional attempt is used instead. A valid completed low Blitz score must not be replaced merely to improve the Student’s result.

- Without an exception, the official Blitz score is ready when Attempt #1 is `checked` (selection policy `valid_normal_blitz`).
- With an approved exception, #1 is excluded and the official Blitz score is ready when replacement #2 exists and is `checked` (selection policy `approved_blitz_exception_replacement`).
- The exception grant withdraws the Student’s existing official Blitz score, if any, in the grant transaction, also when #1 is already checked or official.
- A Blitz closed (or archived) before the Student took replacement #2 has no official Blitz score: the Blitz side is missing and the Student’s Topic result is **Not completed**, even while the invalidated #1 still waits for review (BR-STAT-010A). A #2 taken before the close becomes official once it is `checked`, even when its review ends after the close; while #2 is still being checked or reviewed, the Blitz side waits and is never missing, so the Blitz alone never makes the result **Not completed** (BR-CAT-011).

The grant dialog tells the Teacher these consequences before the exception is granted.

**BR-ATT-021 — Official score resolution and live evaluation**
The official score is re-resolved inside every automatic checking run, review save, correction, and exception grant that concerns an official task, and by the minute sweep (BR-Q-034); it may move to another Attempt. Writers for one Student and one Assessment decide one at a time, so two of them never select concurrently. Between a freeze and its checking run the stored official score can still show the previous result, so no read trusts the stored official score alone: an official score counts as ready, for the Teacher official-score read and for Student visibility (BR-STAT-021), only when the stored official score exists and a live evaluation of BR-ATT-019 steps 1-3, or of the BR-ATT-020 Blitz rules, is ready with the same Attempt and the same normalized score. The sweep also re-resolves the official score of a Student who has a `checked` eligible Attempt and no pending eligible Attempt but whose stored official score is missing or differs from the live evaluation, a state that should not exist. Stage 10 Topic results use the same live evaluation, both for an open result on every read (BR-STAT-010A) and at closure (BR-RES-011A).

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

Designation requires a same-Institution/Topic Blitz in authorized Teacher scope with `assignment_mode = group`, status `draft` or `scheduled`, and no Student Attempt. Active/closed/archived or already-attempted practice Blitz cannot newly become official.

The canonical result-pair PUT requires an eligible official Homework; a pre-existing `topic_result_pairs` row is not required. It may atomically create the one pair with required `homework_assessment_id` and optional eligible non-null `blitz_assessment_id`. Omission preserves any existing Blitz side; no null-clear operation is added. Initial creation sets `designated_by_user_id`, `designated_at`, `created_at`, and `updated_at` once, with `locked_at = null`. Draft Homework leaves `cohort_snapshotted_at = null`; active Homework with a valid persisted official group-recipient snapshot sets it to the designation instant. Pair creation creates no Blitz recipients or Attempts.

An existing pair is reused. Unlocked pairs permit eligible Blitz attach/replacement before activity. Locked pairs may fill a previously-null Blitz side only with unchanged Homework and an eligible candidate honoring the established cohort; a populated locked Blitz side permits only exact same-target no-op. Blitz-only attach/replacement preserves `homework_assessment_id`, `designated_by_user_id`, `designated_at`, `cohort_snapshotted_at`, `locked_at`, and `created_at`; only Blitz identity and real `updated_at` change. Exact same-target replay performs zero writes, including no `updated_at` change. Any allowed Homework replacement independently follows existing Stage 6 rules and alone owns designation/cohort metadata changes.

Creating the first official Blitz Attempt atomically resolves/locks that same pair, verifies official Blitz identity and Student membership in the persisted cohort, and sets a null `locked_at` to the Attempt's `startedAt`; an existing lock is preserved. Start never changes task/cohort identity and practice Blitz never mutates the pair.

### Blitz Structure

**BR-BLZ-006 — Required information**  
Before activation, a Blitz task must contain:

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

The exact stored task statuses are `draft / scheduled / active / closed / archived`. Attempt execution and later Stage 9 checking states are separate.

**BR-BLZ-009 — Draft and scheduled restrictions**  
Students must not start or answer draft or scheduled Blitz tasks before Teacher activation. Scheduling starts no timer and creates no Attempt, checking, or scoring record.

**BR-BLZ-010 — Teacher activation and scoreable points**  
Only an authorized Teacher may activate the Blitz task during class. Draft/Scheduled Blitz may temporarily have zero total points, but immediately before activation the backend must recalculate Question points and require `total_possible_points > 0`; otherwise activation is rejected.

First activation also requires valid title, Topic, Teacher, assignment/instructions, at least one valid Question, `duration_seconds > 0`, eligible lifecycle, and valid recipient/cohort rules. It snapshots recipients, reuses any established official cohort exactly, and creates no Student Attempt. A configured `institution_settings.blitz_timer_start_mode` is required; null returns `409 institution_settings_incomplete` only for activation and does not block drafts, Question authoring, Homework, or ordinary administration.

Activation requires `Idempotency-Key` and authorization before replay. A completed same-key/same-fingerprint activation with valid persisted activation evidence and idempotency result metadata returns `200` current authorized Blitz for `active`, `closed`, or `archived`, without reopening historical work. A completed-success record pointing to `draft`/`scheduled`, or invalid evidence/result metadata, fails closed as an internal integrity inconsistency. Fresh/new-key active activation returns naturally idempotent `200` and may complete its new claim to the same Blitz. Both successful paths perform zero activation-domain mutation: activation time, timer snapshot, synchronized end, recipients, official cohort, and pair identity/lock are preserved. Fresh/new-key closed/archived returns `409 task_closed`/`409 task_archived` with no successful activation result left for that failed request. First eligible draft/scheduled activation follows the readiness rules above; different fingerprint reuse returns `409 idempotency_key_reused`. Activation of the official Blitz additionally follows BR-BLZ-010A.

**BR-BLZ-010A — Homework before Blitz at official activation (`S10-D8`)**
The Blitz checks whether the Student did the Homework alone, so the official Homework ends for the whole class when the official Blitz (the Blitz of the Topic’s result pair) is activated:

- While the official Homework is still a draft, activation returns `409 official_homework_not_activated` and changes nothing. This check runs immediately after the timer-start mode check (BR-BLZ-010) and before the cohort is locked.
- An active official Homework is closed inside the activation transaction exactly like a Teacher Homework close (BR-HW-012). After all its locks, the activation captures one untruncated `closedAt = server_now`; the Blitz `activated_at` is `closedAt` truncated to the UTC second (BR-BLZ-017), while the Homework close uses `closedAt` itself, so it never precedes the Homework’s own `activated_at` or an Attempt’s `started_at`. A passed deadline is reconciled first; every still-`in_progress` Homework Attempt is frozen as `submitted` with `finalization_reason = task_closed_auto_finalize`; the Homework gets `status = closed` and `closed_at = closedAt` with no recorded actor; and the frozen Attempts are then checked automatically (BR-Q-034).
- A closed or archived official Homework is left unchanged.

The close reuses the Homework rows that the activation’s cohort step already locks and takes no lock in another order. The activation response, idempotency, and every other activation conflict are unchanged; an idempotent replay never closes anything. Activation of a practice Blitz is unaffected.

**BR-BLZ-011 — Active-only answering**  
A Student may start or answer the Blitz only while it is active, assigned, within the applicable timing rule, and within the allowed normal or approved exception attempt. Starting normal Attempt #1 of the official Blitz also requires a submitted official Homework Attempt (BR-BLZ-011A).

**BR-BLZ-011A — Homework before Blitz at Student Start (`S10-D8`)**
Only a Student with a submitted Homework Attempt may start the official Blitz. When a `start_normal` request on the official Blitz would create a new normal Attempt #1 (after the existing executability checks, and only when the Student has no Attempt #1), the Student must have at least one terminal (`submitted`, `waiting_for_teacher_review`, or `checked`) Attempt of the official Homework; otherwise the request returns `409 homework_not_submitted` and creates nothing (BR-ATT-004A). A `start_normal` that returns an existing Attempt #1, an idempotent replay, `resume`, and `start_replacement` (the replacement Attempt #2) are unaffected, and so is every practice Blitz. When the activation closed the official Homework, a Student barred this way is **Not completed** at once, with the Homework and Blitz sides both missing (`missing_component = both`, BR-STAT-010A); in history from before Stage 10 with a still-open official Homework, the result waits for the Homework instead (BR-STAT-010B).

**BR-BLZ-012 — Closing/archiving and in-progress attempts**  
Closing an active Blitz atomically blocks Starts and Student answer/file/Submit writes and freezes existing `in_progress` Attempts from already-committed work. Capture one canonical `closedAt`: already-due Attempts become `timed_out_finalized` with `submitted_at = null`, `finalized_at = locked_at = exact deadline_at`, and `finalization_reason = timeout_auto_submit`; only still-pre-deadline Attempts become `submitted` with `submitted_at = null`, `finalized_at = locked_at = closedAt`, and `finalization_reason = task_closed_auto_finalize`. Evaluate each persisted deadline, including different individual/replacement deadlines. Existing terminal reasons/timestamps never change. No Attempt for a never-started Student or answer row for an unanswered Question is fabricated. Saved work remains pending without Stage 8 checking/scoring; Stage 9 later applies zero/checking/review rules. Repeated close is naturally idempotent without a new `Idempotency-Key` requirement. Archive blocks activity and preserves Attempts, exception, and official-pair history.

### Whole-Task Duration and Timer-Start Modes

**BR-BLZ-013 — Teacher-configured whole-task duration**  
The Teacher must configure one positive `duration_seconds` for the entire Blitz task; it cannot silently change after activation. The MVP does not use separate per-question timers. The intended Blitz activity is approximately 5–10 minutes, not a hard validation limit.

**BR-BLZ-014 — Institution-configured timer-start mode**  
Each institution must configure exactly one of these Blitz timer-start modes:

1. **Synchronized start** — the countdown starts for all assigned Students at the moment the Teacher activates the Blitz.
2. **Individual Student start** — Teacher activation makes the Blitz available, but each Student receives the full configured duration beginning when that Student starts the Blitz attempt.

The Institution Admin controls this institution-wide rule. A Teacher must not override it for one task. At activation copy it to immutable `blitz_tasks.timer_start_mode_snapshot`, the exact activated Blitz resource/API name; later Institution setting changes do not affect that Blitz.

**BR-BLZ-015 — Synchronized timer calculation**  
In synchronized mode, persist `synchronized_ends_at = activated_at + duration_seconds`. Normal Attempt #1 uses that shared instant as `deadline_at`; late starters receive only remaining time and cannot create #1 at/after the common end. Replacement #2 is the narrow exception in BR-ATT-017 and never rewrites the shared window.

**BR-BLZ-016 — Individual timer calculation**  
In individual mode, `synchronized_ends_at = null`; normal #1 persists `deadline_at = started_at + duration_seconds`. Replacement #2 uses the same formula from its own Start. Resume preserves the persisted start/deadline.

**BR-BLZ-017 — Backend time is authoritative**  
Blitz timing uses backend-authoritative persisted deadlines. Before comparison, duration arithmetic, persistence, projection, and serialization, floor/truncate raw server execution time to the beginning of its UTC second, never round up. This applies to activation, synchronized end, Attempt start/deadline, response `server_now`/`snapshotAt`, and deadline-based finalization/lock instants. Successful execution timestamps serialize exactly `YYYY-MM-DDTHH:MM:SSZ` with no fractional seconds or hidden fractional operands. `remaining_seconds = max(0, deadline_epoch_second - serverNow_epoch_second)` uses exactly the serialized whole-second instants. Device time/timezone cannot extend eligibility; existing Institution-timezone schedule input rules remain unchanged.

**BR-BLZ-018 — Remaining time visibility**  
The Student must clearly see the remaining time while answering.

### Timeout and Automatic Finalization

**BR-BLZ-019 — Stop editing at timeout**  
When the applicable Blitz timer reaches zero, the system must immediately stop accepting new or changed answers for that attempt.

**BR-BLZ-020 — Automatic timeout finalization**  
When canonical `server_now >= deadline_at`, finalize only an existing `in_progress` Attempt as `status = timed_out_finalized`, `submitted_at = null`, `finalized_at = locked_at = exact deadline_at`, and `finalization_reason = timeout_auto_submit`. Freeze committed answers/files without checking/scoring. The exact persisted deadline wins over delayed request/Scheduler processing time. Student reads, Start/Resume, answer/file writes, Submit, Teacher Close/monitoring, and Scheduler reuse one authoritative reconciliation behavior; every write independently rechecks time, so Scheduler latency never extends eligibility. No fake Attempt or answer row is created and terminal history is immutable.

**BR-BLZ-021 — Unanswered questions receive zero**  
Stage 8 freezes the exact committed answer set without fabricating unanswered rows. Stage 9 later interprets missing/unanswered Questions or components as zero under the approved scoring/partial-credit rules; this does not require Stage 8 awarded-points persistence.

**BR-BLZ-022 — Answered questions are checked normally**  
Every Stage 8 saved answer remains `checking_status = pending` with `awarded_points`, `feedback`, `checked_by_user_id`, and `checked_at` null, including after Submit/timeout/close. Stage 9 later checks objective answers, identifies manual-review answers, performs Teacher review, awards points, and completes scoring. Timeout does not make a valid saved manual answer incorrect, and Stage 8 does not persist a Teacher-review transition.

Answer/file mutation and finalization serialize in a DB transaction with deterministic relevant row locking, locked-state re-read, and authoritative time recheck after locking. Mutation committed first is included in frozen work; finalization committed first permits zero later answer/file-domain mutation, including no persisted file replacement. Only `in_progress` transitions; terminal reasons/timestamps never change.

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
- Waiting for Teacher review (a checked Attempt shows as finalized)
- Approved exception status
- Technical issue status where available

Through Stage 9 monitoring keeps its Stage 8 meaning and shows no scores: a `checked` Attempt still counts as finalized, an Attempt waiting for Teacher review shows as waiting for Teacher review, and the Teacher reads scores through review (BR-Q-037).

**BR-BLZ-024 — Monitoring does not change answers**  
Teacher monitoring must not allow the Teacher to answer on behalf of a Student, change answers, create an Attempt, extend a deadline, change timer mode, or perform Stage 9 checking/points/scoring. Any timeout reconciliation uses the same authoritative finalizer. Tenant scope and protected Student answer/file access remain mandatory.

### Checking and Result Use

**BR-BLZ-025 — Automatic and manual checking**  
Stage 9 applies the same automatic/manual checking and partial-credit rules used for assignment types to frozen Blitz submissions. Stage 8 produces execution/finalization history only.

**BR-BLZ-026 — Blitz score readiness**  
The Blitz score becomes final only after all required automatic and manual checking is complete.

**BR-BLZ-027 — Comparison readiness**  
A final topic calculation must wait until the official Blitz score and official Homework score are both available.

Stage 9 owns both official task scores; Stage 10 owns their comparison, final Topic result, category, and release.

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
When `D > T`, the system must mark homework and blitz as inconsistent. The consistency label, `D`, and `T` are shown only to the Teacher; Students and Parents never see the word “inconsistent”, `D`, or `T` (`S10-D2`, BR-STAT-013B).

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

**BR-CMP-013 — Threshold used**
An open result always compares with the Institution’s current threshold `T` and keeps no copy of it. A closed result records in its closure snapshot the threshold `T` used for its calculation (BR-RES-011A).

**BR-CMP-014 — Threshold changes**
Changing the institution threshold changes every open result on its next read, including a result already visible to the Student or Parent (`S10-D5`, `S10-D6`). It never changes a closed result.

**BR-CMP-015 — Open results follow corrections**
An open result is computed live from the current official scores on every read and is never stored or recalculated (`S10-T1`). When an authorized correction changes an official homework or blitz score before the result is closed, the next read of the result uses the new score with the current threshold. After closure the correction is rejected (BR-RES-011B).

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

With both official scores ready but the threshold or a valid complete category configuration missing, the result is **Waiting for settings** (BR-STAT-007A).

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

### Result Data

**BR-RES-007 — Result contents**
A Topic result identifies, at minimum:

- Institution
- Student
- Topic
- Designated homework assignment
- Designated blitz task
- Homework and Blitz side states (BR-STAT-010A)
- Official homework score and official blitz score, each with its official Attempt, when that side is ready
- Absolute score difference
- Acceptable-difference threshold used
- Calculation method
- Final score and `category_score` when calculated
- Consistency status
- Understanding category
- Result status, closed outcome, and missing component
- Student and Parent visibility, with the Teacher’s release facts
- The Teacher’s Topic-result comment, if any (BR-RES-007A)

An open result is computed live from the current state on every read and is not stored; only what cannot be derived is stored: the Teacher comment, the Teacher release facts, and the closure snapshot (`S10-T1`, BR-RES-011A). The score difference, threshold, calculation method, consistency, final score, and `category_score` exist only for a **Calculated** result, open or closed.

**BR-RES-007A — Teacher comment on the Topic result (`S10-D1`)**
A Topic result carries one optional Teacher comment. Leading and trailing Unicode whitespace (including non-breaking spaces) is trimmed, an empty comment means none, and the comment holds at most 2000 characters after trimming. The Topic’s Teacher (BR-STAT-012) may set, change, or clear it in every result status until the result is closed; after closure the comment cannot change (BR-RES-011B). The Student sees the comment together with the visible result values; the Parent sees it only when the values are visible to the Parent (BR-STAT-016A). There is no separate Parent flag. Teacher feedback on answers (BR-Q-038) stays Student-only.

**BR-RES-008 — Calculation method values**  
A **Calculated** result identifies how its final score was formed, with exactly one of two values:

- `average` — average of homework and blitz (`D <= T`)
- `blitz` — blitz score because of a large difference (`D > T`)

Waiting and **Not completed** are result statuses (BR-STAT-005 to BR-STAT-009), never calculation methods. The Student and the Parent see the method as one neutral line on how the final score was formed (`S10-D2`).

### Manual Corrections and Closure

**BR-RES-009 — No direct final-score manipulation**  
A Teacher must not directly type a different final score that bypasses the approved calculation formula.

**BR-RES-010 — Correct underlying score instead**  
Before result closure, an authorized Teacher may correct a manually reviewed question or task score when the original review was wrong, by correcting the points of the manually reviewed answers (BR-Q-039). The open result then uses the corrected official score on its next read (BR-CMP-015). After closure the correction is rejected (BR-RES-011B).

**BR-RES-011 — Result closure preconditions (`S10-D9`)**
A Teacher may close one Student’s Topic result only when it is closable: it is terminal (open **Calculated** or open **Not completed**, BR-STAT-010B) and the Student’s work is finished (BR-STAT-013A), which is the same moment the result can become visible. With Homework before Blitz (BR-BLZ-010A) that moment is, for every Student, right after the official Blitz closes. **Waiting for homework**, **Waiting for blitz task**, **Waiting for teacher review**, and **Waiting for settings** cannot be closed. Closing a result that is not closable returns `409 result_not_ready_for_closure`; closing an already closed result returns it unchanged.

Closure is Student-and-Topic-specific and needs no class-wide action. Release is independent: it is not a prerequisite for closure, and a closed result can still be released (BR-STAT-019). The Teacher may also close all closable results of a Topic at once (BR-STAT-019A). Archiving the Topic closes every terminal result automatically with closure reason `topic_archived` (BR-TOP-010): at archive every task is closed or archived and no further work is possible, so a terminal result is closable then even when the Student’s work never counted as finished (no activated official Blitz); its values stay hidden from the Student and the Parent (BR-STAT-013A, BR-STAT-013B). Results that still wait stay open at archive. Closing a Topic closes no result. Every Teacher result action serializes with scoring, Student Starts, and exception grants on the same Topic, so closure evaluates one consistent state (`S10-T6`). Reopening a closed result, formal appeals, and post-closure revision are outside the MVP.

**BR-RES-011A — Closure snapshot and stability**
Closure computes the result live inside its own transaction from the current Attempt state and the live evaluation of the official task scores (BR-ATT-021), never from stored official scores alone, and stores the closure snapshot: the closure time, the closing Teacher, the closure reason (`teacher` or `topic_archived`), the closed outcome (`calculated` or `not_completed`), the missing component, the pair’s Homework and Blitz, both side states, the official Attempts and scores of the ready sides, and for a **Calculated** outcome the score difference, the threshold, the calculation method, the consistency, the final score, `category_score`, the category, and the category range used. The snapshot references the official Attempts, which are never deleted, and never the stored official task-score rows (`S10-T2`). After closure the snapshot and the Teacher comment never change, and the result never reads current settings again (`S10-D6`); only the Teacher release facts can still be recorded.

**BR-RES-011B — What closure blocks (`S10-T7`)**
For a Student whose Topic result is closed:

- a correction of that Student’s official Homework or official Blitz answer returns `409 result_closed` (BR-Q-039);
- a change of the Teacher comment returns `409 result_closed`, also for an unchanged value (BR-RES-007A);
- a Start of the official Homework returns `409 result_closed` after the existing lifecycle, deadline, and attempt-count conflicts. This is reachable only in history from before Stage 10: a Homework with no Attempt at all whose deadline a Teacher moved later.

Closure needs finished work, so the official Blitz is already closed, or the Topic is archived (BR-RES-011): a Blitz Start, an exception grant, and a result-pair change cannot happen after closure (`result_pair_locked` and `topic_not_editable` already apply) and get no closure guard. Still allowed after closure: a first review of a still-waiting answer, automatic checking, and the sweep. For a **Calculated** closure no pending Attempt could overtake, so such a review cannot change the official score; for a **Not completed** closure a later first review may still complete the other side’s official score in the Stage 9 views, but it never changes the closed snapshot. Idempotent replays of an earlier successful request keep returning the stored response. Practice tasks are never affected.

**BR-RES-012 — Calculation precision, display rounding, and category score (`S10-T5`)**
Homework and Blitz normalized scores are the stored Attempt scores of BR-Q-036: exact decimal arithmetic with one half-up rounding to 8 decimal places when stored. The score difference, the threshold comparison, and the final score are computed exactly from those stored scores and the threshold `T`, with no intermediate rounding and never from the one-decimal display value. The exact final score (an average can need a ninth decimal place) is stored and serialized rounded half-up to 8 decimal places. For understanding-category assignment only, the system derives an integer `category_score` from the exact final score: a fractional part from `.0` through `.5` rounds down to the lower integer; a fractional part greater than `.5` rounds up to the next integer (`85.5 → 85`, `85.50000001 → 86`). The category is resolved from this integer score, not from the one-decimal display value and not directly from the decimal final score. User-facing Homework, Blitz, and final scores, and the score difference and threshold shown to the Teacher, are displayed by the client from the stored value rounded to **one decimal place** using standard (half-up) mathematical rounding. Display rounding never changes the category or the consistency, so a Teacher may correctly see an inconsistent result whose displayed difference equals the displayed threshold.

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
After the final score is calculated, the backend derives exactly one integer `category_score` from the exact final score (BR-RES-012): fractions `.0` through `.5` round down, while fractions greater than `.5` round up. The category resolver then maps that integer to exactly one configured category range: for an open result, the range of the Institution’s current category configuration that contains it; for a closed result, the category and range stored in its closure snapshot. A stored configuration that fails the category-configuration validation counts as missing, and the result is **Waiting for settings** (BR-STAT-007A). Example: `85.5 → 85`, `85.50000001 → 86`, and `85.6 → 86`.

### Not Completed

**BR-CAT-008 — Not completed is not a numeric score band**  
The **Not completed** category must be based on missing required work, not a low numeric score.

**BR-CAT-009 — Not completed trigger**  
A Topic result receives **Not completed** as soon as one side (official homework or official blitz) is missing, that is, the Student can no longer complete it after the applicable attempts, deadline, active period, or task closure (BR-STAT-010A), even while the other side is still open or waiting for review (`S10-T3`). A side the Teacher never designated or never activated is never missing: the result waits.

**BR-CAT-010 — Show missing component**  
The system must show whether the missing component is:

- Homework (`homework`)
- Blitz task (`blitz`)
- Both homework and blitz (`both`)

The missing component names the sides that are missing now; it can change (for example from `homework` to `both`) until the result is closed.

**BR-CAT-011 — Waiting for review is not Not completed**  
A side that waits for automatic checking or Teacher review is never missing, so review alone never makes a result **Not completed**. A result is **Not completed** only because some side is missing, even while the other side still waits for review (`S10-T3`). Review of an Attempt that cannot affect an official score (an invalidated Blitz #1, a Homework Attempt that cannot overtake) never keeps a side waiting (BR-ATT-019, BR-ATT-020).

**BR-CAT-012 — Not released is not Not completed**  
A calculated result that has not been released to the Student or Parent must not receive **Not completed** for that reason. A result waiting for settings is likewise never **Not completed** (BR-STAT-007A).

### Category Changes and Visibility

**BR-CAT-013 — Category range at closure**
A closed result retains, in its closure snapshot, the category, `category_score`, and category range used when it was closed (BR-RES-011A). An open result stores no category; it always resolves the category from the Institution’s current configuration (`S10-D6`).

**BR-CAT-014 — Category setting changes**
Changing institution category ranges applies to every open result on its next read, including a result already visible to the Student or Parent (`S10-D5`), and never changes a closed result.

**BR-CAT-015 — Teacher visibility**  
The Teacher may view the category and `category_score` for assigned Students when the result is available (BR-STAT-012).

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
- Invalidated by approved exception (Blitz only; derived, see BR-STAT-004A)
- Not completed

**BR-STAT-004 — Status belongs to the Student submission**  
Submitted, waiting for review, checked, invalidated-by-exception, and not-completed states must be tracked per Student submission or requirement, not used as a replacement for task lifecycle status. Stage 7 Homework transitions only from editable `in_progress` to frozen `submitted`; `submitted` does not imply explicit Student Submit or completed checking. Only Stage 9 Homework checking may later move that history to `waiting_for_teacher_review` or `checked`. Stage 8 Blitz freezes execution as `submitted` or `timed_out_finalized`; timeout uses `timeout_auto_submit` at exact `deadline_at` and does not mean checking/scoring is complete. Only Stage 9 later creates Blitz review/checked states.

**BR-STAT-004A — Invalidated status is derived**
The Student-facing status **Invalidated by approved exception** is derived from `official_score_eligible = false` on a Blitz Attempt #1 after an approved exception; it is not a stored Attempt status. The invalidated Attempt’s stored status follows normal checking (BR-Q-033, BR-Q-035).

### Result Calculation Statuses

A Topic has Topic results only after its official cohort is established (`cohort_snapshotted_at` is set, BR-TOP-004A): one result for each Student of the cohort, the persisted recipients of the official Homework and the official Blitz. Before that the Topic has no results, and later Group membership changes never change the cohort. An open (not closed) result is computed from the current state on every read; it is never stored and never recalculated by a job (`S10-T1`). A closed result is read only from its closure snapshot (BR-RES-011A).

The MVP result statuses (`result_status`) are:

- **Waiting for homework** (`waiting_for_homework`)
- **Waiting for blitz task** (`waiting_for_blitz`)
- **Waiting for teacher review** (`waiting_for_teacher_review`)
- **Waiting for settings** (`waiting_for_settings`)
- **Calculated** (`calculated`)
- **Not completed** (`not_completed`)
- **Closed** (`closed`)

The first six are statuses of an open result and follow the precedence of BR-STAT-010B.

**BR-STAT-005 — Waiting for homework**  
Use this status while no side is missing, the two official scores are not both ready, and the official Homework is not yet activated, can still be worked on by the Student, or has an official score still being checked automatically (BR-STAT-010B row 4).

**BR-STAT-006 — Waiting for blitz task**  
Use this status while no earlier row of BR-STAT-010B applies and the official Blitz is not yet designated or activated, can still be worked on by the Student (including a pending approved replacement), or has an official score still being checked automatically (BR-STAT-010B row 5).

**BR-STAT-007 — Waiting for teacher review**  
Use this status when no earlier row of BR-STAT-010B applies and an official Homework or Blitz score still waits for manual scoring (BR-STAT-010B row 6).

**BR-STAT-007A — Waiting for settings**
Use this status when both official scores are ready but the Institution has no acceptable-difference threshold or no valid complete category configuration; a stored configuration that fails the category-configuration validation counts as missing (`S10-T4`). The result becomes **Calculated** on its next read after the settings are configured. It is never **Not completed**.

**BR-STAT-008 — Calculated**  
Use this status after both official scores are available and the Institution has a threshold and a valid complete category configuration: the formula has been applied with the current threshold and the category resolved from the current ranges (`S10-D6`). An open Calculated result still follows later corrections and setting changes until it is closed.

**BR-STAT-009 — Not completed**  
Use this status when some side is missing (BR-STAT-010A): the Student can no longer complete it, even while the other side is still open or waiting for review (`S10-T3`). The missing component (`homework`, `blitz`, or `both`) names the sides missing now and can change until the result is closed (BR-CAT-010). A Not completed result has the **Not completed** category and no final score, score difference, threshold, consistency, calculation method, or `category_score`.

**BR-STAT-010 — Closed**  
Use this status when the final result is finalized by closure (BR-RES-011) and no further changes are permitted in the MVP. A closed result has `result_status = closed` and a closed outcome of `calculated` or `not_completed` (the closed outcome is null for every open result); all its values come from its closure snapshot (BR-RES-011A).

**BR-STAT-010A — Side states**
Each side (Homework, Blitz) of one cohort Student has exactly one state, the first matching row. The official-score status is the Stage 9 live read (BR-ATT-021): ready only while the stored official score matches the live evaluation.

Homework side:

| # | Condition | Side state |
|---|---|---|
| 1 | Official score status `ready` | `ready` (value H, official Attempt) |
| 2 | Official score status `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 3 | Official score status `automatic_checking_pending` | `checking` |
| 4 | The official Homework was never activated | `not_activated` |
| 5 | The Student has an `in_progress` Attempt | `open` |
| 6 | The Homework is active, has no deadline or `server_now < deadline_at`, and the Student has fewer than three Attempts | `open` |
| 7 | Otherwise (closed or archived, deadline passed, no checked or pending Attempt) | `missing` |

Blitz side:

| # | Condition | Side state |
|---|---|---|
| 1 | The pair has no Blitz | `not_designated` |
| 2 | Official score status `ready` | `ready` (value B, official Attempt) |
| 3 | Official score status `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 4 | Official score status `automatic_checking_pending` | `checking` |
| 5 | Official score status `waiting_for_replacement` | `open` |
| 6 | The official Blitz was never activated (draft, scheduled, or archived before activation) | `not_activated` |
| 7 | The Blitz is active, the Student has no Blitz Attempt, and the Homework side is `missing` (the Student can no longer get the submitted Homework that BR-BLZ-011A requires to start) | `missing` |
| 8 | The Blitz is active | `open` |
| 9 | Otherwise (closed or archived after activation; never started, or an exception without a taken replacement, even while #1 waits for review, BR-ATT-020) | `missing` |

A side that waits for automatic checking or Teacher review is never missing. A side the Teacher never designated or never activated is never missing: the result waits (`S10-T3`).

**BR-STAT-010B — Status precedence for open results**
An open result has the status of the first matching row:

| # | Condition | `result_status` |
|---|---|---|
| 1 | Some side is `missing` | `not_completed`; missing component `homework`, `blitz`, or `both` (the sides that are `missing` now) |
| 2 | Both sides `ready`, and the Institution has a threshold and a valid complete category configuration | `calculated` |
| 3 | Both sides `ready`, threshold or category configuration missing | `waiting_for_settings` |
| 4 | Homework side `not_activated`, `open`, or `checking` | `waiting_for_homework` |
| 5 | Blitz side `not_designated`, `not_activated`, `open`, or `checking` | `waiting_for_blitz` |
| 6 | Otherwise (a side `waiting_for_teacher_review`) | `waiting_for_teacher_review` |

The missing component is null for every other status. The precedence is Homework, then Blitz, then Teacher review (`S10-T3`). An open result is **terminal** when its status is `calculated` or `not_completed`.

### Visibility State

**BR-STAT-011 — Visibility is independent**  
A result’s status and its visibility must be evaluated separately: visibility never changes a status or value, and a status never depends on visibility.

**BR-STAT-012 — Teacher access**  
Topic results are read and changed by the Topic’s Teacher: the Teacher who owns the Topic and is a current Teacher of its group (the review access rule of BR-Q-037, `S10-T6`). Topic and task status never restrict this access. The Teacher sees every cohort Student’s result with its status, both side states, official scores, score difference, threshold, consistency, calculation method, final score, `category_score`, category, comment, and Student and Parent visibility, even when the result is not visible to the Student or Parent (`S10-D2`).

**BR-STAT-013 — Student result-release modes**  
Each institution must configure one Student result-release mode:

- **Automatic** — the Topic result values become visible to the Student by themselves at the moment the result is terminal or closed and the Student’s work is finished (BR-STAT-013A).
- **Manual Teacher release** — the Teacher’s release to the Student becomes available at that moment (BR-STAT-019); the values stay hidden from the Student, while visible to the Teacher, until the Teacher releases them.

While the mode is unconfigured, no result becomes visible through the mode and no new Teacher release is possible (BR-INST-016B).

**BR-STAT-013A — Work-finished window (`S10-D3`)**
A Student’s work on a Topic is finished when all of these hold:

- the official Blitz was activated and is now closed or archived;
- the official Homework is closed or archived, or its deadline has passed (`deadline_at <= server_now`), or the Student has used all three Attempts;
- the Student has no `in_progress` Attempt on the official Homework or the official Blitz.

A Topic without an official Blitz never has finished work for visibility. Because the official Blitz activation closes the official Homework (BR-BLZ-010A), every Student’s work is finished right after the official Blitz closes, so a Student who finishes the Blitz early never sees a Topic result before the Blitz closes. A Homework deadline moved later or removed (possible only while the Homework has no Attempt, so only in history from before Stage 10) closes the window again for an open result; a result closed with finished work, which every Teacher closure requires (BR-RES-011), always counts as finished. A result closed at Topic archive without finished work (no activated official Blitz) never counts as finished, so its values stay hidden.

**BR-STAT-013B — Student view of the Topic result**
The Topic result values (Homework score, Blitz score, final score, calculation method, category, and the Teacher’s comment) are visible to the Student exactly when all of these hold:

```text
result is terminal or closed
+ the Student's work is finished (BR-STAT-013A)
+ (student_result_release_mode = automatic  or  the Teacher released the result to the Student)
```

When visible, the Student sees the values that exist: a **Not completed** result shows the ready side’s score, the **Not completed** category, and the comment, with no final score or calculation method. The status (result status, closed outcome, and missing component) is always visible to the Student (BR-STAT-018). The Student never sees the score difference, the threshold, the consistency (never the word “inconsistent”), or `category_score` (`S10-D2`). A cohort Student keeps access to the Topic result after leaving the group (BR-REL-010).

**BR-STAT-014 — Parent result-visibility modes**  
Each institution must configure one Parent result-visibility mode:

- **With Student release** — a connected Parent sees the result values whenever they are visible to the Student (BR-STAT-013B).
- **Manual Teacher release** — a connected Parent sees the result values only after an authorized Teacher releases the result to Parents, and only while they are visible to the Student.
- **Hidden** — Parents receive no Topic result information at all, not even the status (`S10-T8`).

An unconfigured Parent mode behaves as **Hidden**.

**BR-STAT-015 — Parent never ahead of the Student**
A Parent never sees result values that are not visible to the Student at that moment, regardless of the Parent visibility mode. A Teacher release to Parents is possible only while the values are visible to the Student (BR-STAT-019).

**BR-STAT-016 — Separate Student and Parent visibility**  
Student visibility and Parent visibility must be evaluated separately, and the Teacher’s releases to the Student and to Parents are recorded separately, so the institution’s approved modes can be enforced.

**BR-STAT-016A — Parent view of the Topic result**
A Parent sees Topic result information only for a Student with a current Parent–Student relationship (BR-REL-011, BR-REL-014) and only for a Topic that Student can access. In **Hidden** or unconfigured Parent mode the Parent receives nothing. Otherwise the Parent sees the status (result status, closed outcome, and missing component) and, when the values are visible to the Parent (BR-STAT-014, BR-STAT-015), the same values as the Student, including the Teacher’s comment (`S10-D1`). The Parent never sees the score difference, the threshold, the consistency, `category_score`, or Teacher feedback on answers. Stage 10 provides one Parent read of a child’s Topic result; Parent screens, the children list, dashboards, and progress are Stage 11.

**BR-STAT-017 — Release does not change the result**
Releasing a result must not change the scores, formula, category, consistency, or status. The MVP has no hide or unrelease action (`S10-D5`).

**BR-STAT-017A — Released results and later changes (`S10-D5`, `S10-D6`)**
A released result stays released. After a Teacher correction the Student and the Parent see the new values at once; if the result falls back to a waiting status, they see that status without values and later the new result, with no new release. A change of a release mode acts immediately on every result, and the Teacher releases already made stay: for example, switching from automatic to manual Teacher release hides the values a Student saw only through the automatic mode until the Teacher releases them. A change of the threshold or the category ranges changes every open result at once, including one already visible; a closed result never changes.

**BR-STAT-018 — Status visibility**
The Topic result status (result status, closed outcome, and missing component) is always visible to the Student, and to the Parent unless the Parent mode is **Hidden** or unconfigured, without exposing values that are not visible. An Attempt status `checked` stays visible to the Student without its score while the Attempt result is not visible (BR-STAT-020; carried item `CL9-10` accepted).

**BR-STAT-019 — Teacher release authority**  
Only the Topic’s Teacher (BR-STAT-012) may release a result, and only while the current mode for that audience is manual Teacher release; each release is checked in this order:

- **Release to the Student** — when the current Student mode is not manual Teacher release, `409 manual_release_not_allowed`; when already released to the Student, the result is returned unchanged; when the result is neither terminal nor closed, or the Student’s work is not finished (BR-STAT-013A), `409 result_not_ready`; otherwise the release is recorded with its time and Teacher.
- **Release to Parents** — when the current Parent mode is not manual Teacher release, `409 manual_release_not_allowed`; when already released to Parents, the result is returned unchanged; when the values are not visible to the Student now (BR-STAT-013B), `409 student_result_not_released`; otherwise the release is recorded with its time and Teacher.

A closed result can be released like any other (release stays separate from closure, BR-RES-011A). A release never changes a value or status (BR-STAT-017).

**BR-STAT-019A — Bulk result actions (`S10-D7`)**
Besides the single-Student close and releases, the Topic’s Teacher may, for all cohort Students of one Topic at once: close all closable results, release to Students all results ready for release, and release to Parents all results visible to Students. Each bulk action applies the single-Student rule (BR-RES-011, BR-STAT-019) to every cohort Student in one transaction, changes only eligible results, and reports how many results it processed and how many it skipped and why: already done (already closed, or already released to the Student or to Parents) or not ready. A mode that forbids the release fails the whole bulk release with `409 manual_release_not_allowed`.

### Student Attempt Result Visibility

**BR-STAT-020 — Student view of own Attempt results (`S10-D4`)**
A Student sees the result of an own Attempt (its normalized score and the Teacher’s feedback on its answers) only when all of these hold:

```text
attempt.status = checked
+ attempt.official_score_eligible = true
+ (Homework) or (Blitz with status closed or archived)
+ (practice task) or (student_result_release_mode = automatic) or (the Teacher released the Student's Topic result to the Student)
```

Answer feedback is shown only when the result is visible and the Teacher wrote feedback. Practice (non-official) task results are not governed by the release mode: they are visible after checking in every mode (a practice Blitz after it closes). A manual Teacher release of the Topic result (BR-STAT-019) also makes that Student’s official Homework and Blitz Attempt results and answer feedback visible. This rule replaces the Stage 9 rule, which required the automatic mode for every Attempt; only which values are visible changes. These conditions are what a released result means for a Student’s own Attempt results (BR-ROLE-018, BR-ACL-008).

**BR-STAT-021 — Student view of Homework Attempts and the official Homework score**
A Student sees every own terminal Homework Attempt in `attempt_number` order, each with its result only when visible under BR-STAT-020. For the official Homework, the Student also sees the official Homework score and the number of the Attempt it came from exactly when that official score is ready under the live evaluation of BR-ATT-021 and the release condition of BR-STAT-020 holds (the Student mode is automatic, or the Teacher released the Student’s Topic result to the Student).

**BR-STAT-022 — Student view of finished Blitz tasks**
A Student sees own Blitz tasks (persisted recipient) that were activated and are now closed or archived, most recently finished first. Each shows whether the first Attempt was invalidated by an approved exception and the result of the counting Attempt (replacement #2 when an exception exists, otherwise #1), if that Attempt exists; its score and answer feedback appear only when visible under BR-STAT-020. An invalidated Blitz Attempt #1 never shows a score; the Student sees it as invalidated.

**BR-STAT-023 — Never exposed to a Student; Parent boundary**
A Student never sees correct answers, answer keys, per-Question awarded points, per-answer checking status, reviewer identity, or the Homework review deadline. A Parent never sees Teacher feedback on answers (`S10-D1`); in Stage 10 a Parent receives result information only through the child’s Topic result under BR-STAT-016A.

---

## 15. Submission and Editing Rules

### Starting and Saving Work

**BR-SUB-001 — Own-task submission only**  
A Student may start or submit only a task assigned to that Student.

**BR-SUB-002 — Valid active context required**  
The task, Student account, and institution must be active, and deadline/time/attempt rules must permit the action.

**BR-SUB-003 — One Student owns the attempt**  
An attempt and submission must be permanently connected to the authenticated Student. Another Student or Parent must not submit on that Student’s behalf.

**BR-SUB-004 — Automatic answer saving**
Student answers on an editable `in_progress` Homework or Blitz Attempt are saved automatically; there is no Save button. A typed answer is saved one second after the Student's last change, at once when the Student leaves a text field, before Submit, and when the app goes to the background. A file answer uploads as soon as the Student chooses the file; a file the server rejects is dropped with its error and the saved file is kept. Each saved/replaced answer remains `checking_status = pending` with `awarded_points`, `feedback`, `checked_by_user_id`, and `checked_at` null. A Question the Student never answered requires no `attempt_answers` row merely to represent zero. Nothing is saved after the Blitz time has run out on the device or on the server. Offline drafts are not an MVP requirement.

### Final Submission

**BR-SUB-005 — Explicit submission and authoritative auto-finalization**  
For Homework, explicit Student Submit before deadline freezes the `in_progress` Attempt as `status = submitted` using one captured `finalizedAt = server_now` for `submitted_at`, `finalized_at`, and `locked_at`, with `finalization_reason = student_submit`. Deadline or Teacher-close finalization also ends as immutable `submitted`, but leaves `submitted_at = null` and uses the authoritative reason/time defined in BR-HW-012/016. Every Stage 7 path freezes only already-committed Student work and leaves answers pending for Stage 9.

For Blitz, pre-deadline explicit Submit freezes only own editable `in_progress` work as `submitted`, with `submitted_at = finalized_at = locked_at =` the canonical server submit instant and `finalization_reason = student_submit`. Saved answers remain pending for Stage 9. Late Submit first commits required timeout reconciliation and returns `409 blitz_time_expired` without a successful or incomplete new claim. A new request against a terminal Attempt with `finalization_reason = timeout_auto_submit` returns `409 blitz_time_expired`, whatever its later checking status; any other terminal execution/checking history returns `409 attempt_not_editable`. Completed successful same-key Submit replay returns `200` without mutation when the original `student_submit`, non-null `submitted_at`, and equal finalization/lock timestamps remain intact, including later valid review/checked states.

Stage 8 requires durable DB-backed `idempotency_records` for exactly `student.blitz.attempt.start`, `student.blitz.attempt.submit`, `teacher.blitz.activate`, and `teacher.blitz.attempt_exception.grant`. The existing `student.homework.attempt.submit` identity remains separate and unchanged; no Assessment-independent Submit operation is substituted. Valid same-key/same-fingerprint replay preserves its logical result after authorization; different fingerprint reuse returns `409 idempotency_key_reused`. Answer/file mutations, Teacher Close, schedule, archive, and result-pair PUT gain no key requirement here.

**BR-SUB-005A — Checked history stays readable and replayable**
Stage 9 checking never changes a Stage 7/8 outcome. Student reads and same-key Submit replays of a terminal Homework or Blitz Attempt are served without error in every checking state (`submitted`, `timed_out_finalized`, `waiting_for_teacher_review`, or `checked`), including answers already `auto_checked`, `waiting_for_teacher_review`, or `teacher_checked`. A replay of a completed Homework or Blitz Submit returns the Attempt in its current status, which may be `waiting_for_teacher_review` or `checked`; all finalization fields stay unchanged. Blitz timeout responses stay keyed on `finalization_reason = timeout_auto_submit` (BR-ATT-004A, BR-SUB-005).

**BR-SUB-006 — Submission validation**  
Before accepting a final submission, the system must validate:

- Student assignment
- Task status
- Attempt availability
- Deadline or blitz time
- Required answers where applicable
- For Stage 7 Homework, an unanswered Question does not require a fabricated answer row; only answer payloads actually provided must pass structural validation
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

For Stage 7 Homework specifically, finalization also records the authoritative reason/timestamps, preserves only already-committed answers/private file references as pending, and leaves score, awarded points, checking/review metadata, and Teacher feedback unavailable until Stage 9.

**BR-SUB-008 — Final submission locks the attempt**  
After final submission for any task, the Student must not change that Attempt's answers. For Homework, the same prohibition applies after Submit, deadline, or Teacher-close finalization: answer/file mutation and finalization must serialize through the relevant Homework/Attempt lock boundary and re-read lifecycle, authoritative time, and editability after locking. If the Student mutation commits first, that committed state is part of the frozen Attempt. If finalization commits first, the later mutation performs zero answer/file-domain mutation and returns the documented lifecycle/deadline/editability conflict. A rejected file replacement must leave persisted file identity/content unchanged. Existing Blitz final-submission/timeout write protection remains unchanged.

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

Result closure needs finished work or a Topic archive (BR-RES-011), so no Attempt of the official tasks is still editable when a result is closed; a later Start of the official Homework returns `409 result_closed` after the existing lifecycle, deadline, and attempt-count conflicts (BR-RES-011B).

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
Only the submitting Student and an authorized Teacher reviewer may access a submitted answer file. A Teacher may download it only when its answer belongs to a submission the Teacher may review (BR-Q-037). A file of an `in_progress` Attempt is available only to its Student. Every other request receives a privacy-safe not-found response. Parent access is limited to allowed progress information unless file viewing is separately approved.

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
| Scores/results | Platform statistics | Institution summaries | View assigned, score manual work, comment, release, and close | View own when visible | View child when visible to the Parent |
| Institution settings | Global platform settings only | Manage own institution | Task-level settings only | No | No |

### View and Edit Separation

**BR-ACL-006 — View does not imply edit**  
Permission to view a record must not automatically grant permission to edit it.

**BR-ACL-007 — Parent view-only**  
Parent access is read-only in the MVP.

**BR-ACL-008 — Student own-data restriction**  
A Student may view only their own submissions and their own results when visible (BR-STAT-013B, BR-STAT-020).

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
- Writing the Teacher comment on a Topic result
- Closing Topic results
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
- “This result is closed and can no longer be changed.”
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
19. Stage 8 Blitz timeout freezes committed pending work; Stage 9 later applies unanswered-zero/checking/scoring rules.
20. Recording one official Homework score and one official Blitz score.
21. Partial-credit scoring for multiple-choice, matching, ordering, and fill-in-the-blank according to the approved rules.
22. Automatic/manual scoring for the remaining supported question types according to the approved rules.
23. Absolute Homework–Blitz score difference using the stored normalized scores, never display-rounded values.
24. Institution-configured acceptable score difference.
25. Average score when results are close.
26. Blitz score when the difference is large.
27. One-decimal user-facing score display, exact decimal scoring with one half-up rounding to 8 decimal places when scores are stored, and integer `category_score` category resolution.
28. Consistency and inconsistency labels without automatic accusations.
29. Five understanding categories.
30. Institution-configured inclusive integer category ranges.
31. A non-numeric **Not completed** category for missing required work.
32. Separate task, submission, result, and visibility states.
33. Institution-configured Student release mode: automatic or manual Teacher release.
34. Institution-configured Parent visibility mode: with Student release, manual Teacher release, or hidden.
35. Teacher result review, single and bulk release where configured, and result closure: single and bulk only when the Student’s work is finished, and automatic on Topic archive for every terminal result (BR-RES-011, BR-TOP-010).
36. Platform upload maxima of 25 MB for learning materials and 15 MB for Student answer files, with institutions allowed to configure lower limits.
37. UTC authoritative timestamps with one configurable IANA timezone per institution.
38. Basic institution and group progress summaries.
39. Server-side role and record-scope permission checks.
40. Historical preservation through closure, archiving, deactivation, and invalidated Blitz-attempt history.
41. An optional Homework review deadline that is a reminder only and never changes scores (BR-HW-018A).
42. Live open Topic results with seven result statuses, visible to Students and Parents only after the Student’s work is finished, and a closure snapshot for closed results (BR-STAT-010B, BR-STAT-013A, BR-RES-011A).
43. One optional Teacher comment per Topic result, visible together with the result values (BR-RES-007A).
44. Homework before Blitz: the official Blitz activation closes the official Homework, and only a Student with a submitted Homework Attempt may start the official Blitz (BR-BLZ-010A, BR-BLZ-011A).

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
- Hiding or unreleasing a released result, reopening a closed result, or revising it after closure
- Negative marking
- Teacher choice of the official Attempt
- Showing Students correct answers or per-Question points
- Review history beyond the last reviewer and review time

### Resolved MVP Business Decisions

The previously open MVP decisions are now approved and are mandatory:

1. **Homework attempts and official score** — Homework allows exactly three normal attempts. The highest valid completed, fully checked normalized score becomes the official Homework score once no pending Attempt could still overtake it (BR-ATT-019).
2. **Blitz attempts and exception** — Blitz allows exactly one normal attempt. A new technical exception requires exactly active Blitz, an authorized Teacher, persisted recipient, terminal or canonically timeout-finalized normal #1, and no prior exception/#2. Pre-deadline editable #1 rejects the grant. Closed Blitz permanently rejects new grants; an elapsed common synchronized end alone does not block an otherwise valid active grant. The required reason and one exception row authorize Student-started replacement #2; original #1 remains immutable and is excluded from later official scoring, and the grant withdraws any official Blitz score already based on #1 (BR-ATT-020). #2 gets the full existing duration from its own Start in either mode without changing the class timer.
3. **Blitz timer-start mode** — Each institution selects synchronized start or individual Student start. The Teacher configures one whole-task duration; there are no per-question timers in the MVP.
4. **Blitz timeout** — Stage 8 freezes committed pending answers at exact `deadline_at` as `timed_out_finalized` with `timeout_auto_submit`, without fake rows, points, or review transitions. Stage 9 later applies unanswered-zero rules, objective checking, and Teacher review.
5. **Partial credit** — Multiple-choice limits Student selections to the number of correct options and awards credit only for correctly selected answers; matching uses correct pairs; ordering uses correctly positioned items; fill-in-the-blank uses correctly completed blanks. Single-choice, true/false, and automatically checked short answers are all-or-nothing. Manual written/file answers are scored by the Teacher within allowed points.
6. **Score precision, display, and category rounding** — Scoring uses exact decimal arithmetic with one half-up rounding to 8 decimal places when awarded points and normalized scores are stored (BR-Q-036). Homework/Blitz comparison and final-score calculation use those stored scores with no further intermediate rounding. User-facing scores display one decimal place. Category assignment uses the derived integer `category_score`: `.0`–`.5` rounds down and `>.5` rounds up.
7. **Result release** — Student mode is either automatic or manual Teacher release. Parent mode is with Student release, manual Teacher release, or hidden. Topic result values become visible only after the Student’s work is finished (BR-STAT-013A). A Parent sees values only while they are visible to the Student, and in hidden mode receives no result information. A released result stays released (BR-STAT-017A).
8. **Upload limits** — Platform maximum is 25 MB per learning-material file and 15 MB per Student answer file. Institutions may configure lower, never higher, limits.
9. **Timezone** — Authoritative instants are stored as UTC. Each institution uses one configurable IANA timezone for educational date/time entry and display; device time does not control validity, and timezone changes do not alter historical absolute instants.
10. **Result-bearing tasks** — A Topic may contain multiple Homework and Blitz tasks, but exactly one whole-group Homework + one whole-group Blitz form the eventual official result-bearing pair. Selected-Student tasks are practice-only. The first activated official task establishes the persisted official cohort, and the later task reuses it. Student activity locks the already-designated task/cohort; attaching a previously absent official Blitz completes the pair and is not replacement.

These decisions are no longer implementation choices. Backend, frontend, database, API contracts, tests, and Codex tasks must implement them consistently.

### Post-Audit MVP Rules

The final cross-document audit added the following mandatory clarifications:

1. Automatic Short Written checking and Fill-in-the-Blank blanks use the deterministic normalized exact matching of BR-Q-013A: Unicode NFC, full case folding, NFC again, normalized apostrophe variants, one space for each whitespace run, and trim, in that order; punctuation and other symbols remain significant and fuzzy/AI matching is excluded.
2. Draft assessments may have zero total points, but Homework/Blitz activation requires a backend-recalculated `total_possible_points > 0`.
3. If highest Homework scores tie exactly, the lowest `attempt_number` is the official attempt reference.
4. Closing active Homework before its deadline freezes every existing `in_progress` Attempt as `submitted` from already-committed pending work with `task_closed_auto_finalize`, creates no fake Attempt/answer row, and leaves checking/scoring to Stage 9. Closing active Blitz likewise freezes committed pending work without checking/scoring: due Attempts retain timeout reason/exact deadline; only pre-deadline Attempts use `submitted` with `task_closed_auto_finalize` at captured close time. Existing terminal history remains immutable.
5. Administrator-created accounts require first-login password change and normal application access is blocked until the change succeeds.
6. Result closure requires a terminal Student+Topic state and, for a Teacher closure, the Student’s finished work (BR-RES-011; the Topic archive closes every terminal result) and remains independent from visibility/release.

### Second-Audit Homework Deadline Decision — Resolved

The final post-audit deadline rule is approved: an `in_progress` Homework Attempt is frozen at the authoritative Homework deadline as `submitted` using already-committed saved work, with `submitted_at = null`, `finalized_at = locked_at = deadline_at`, and `homework_deadline_auto_submit`. Stage 7 leaves saved answers pending, fabricates neither an answer row for an unanswered Question nor an Attempt for a never-started Student, makes unused remaining attempts unavailable, and rejects later answer/file/Submit mutation. Stage 9 later checks the frozen history and treats missing answers as zero under the approved policy. No Homework-deadline behavior remains open.

### Stage 10 Result Decisions (Project Owner, 2026-10-03)

| ID | Decision | Rules |
|---|---|---|
| `S10-D1` | One optional Teacher comment per Topic result; the Parent sees it only with Parent-visible values; no Parent flag; answer feedback stays Student-only; the comment cannot change after closure. | BR-RES-007A, BR-Q-040, BR-HW-025 |
| `S10-D2` | Student and Parent see H, B, final score, category, completion status, Teacher comment, and the calculation method; never “inconsistent”, `D`, or `T`. The Teacher sees everything. | BR-STAT-012, BR-STAT-013B, BR-STAT-016A |
| `S10-D3` | Visibility only after the Student’s work is finished (official Blitz activated and now closed or archived, and official Homework no longer submittable). | BR-STAT-013, BR-STAT-013A |
| `S10-D4` | A manual Topic release also shows the official Attempt results and answer feedback; practice results are visible after checking in every mode. | BR-STAT-020, BR-STAT-021 |
| `S10-D5` | A released result stays released and follows corrections; no hide or unrelease action. | BR-STAT-017, BR-STAT-017A |
| `S10-D6` | Open results use the current threshold and category ranges; closed results are frozen; release-mode changes act immediately and keep existing releases. | BR-INST-018, BR-CMP-013, BR-CMP-014, BR-CAT-013, BR-CAT-014, BR-STAT-017A |
| `S10-D7` | Single and bulk close and release; bulk actions report skipped results; Topic archive closes every terminal result. | BR-STAT-019A, BR-RES-011, BR-TOP-010 |
| `S10-D8` | Homework before Blitz: official Blitz activation closes the official Homework and is refused while it is a draft; only a Student with a submitted Homework Attempt may start the official Blitz. | BR-BLZ-010A, BR-BLZ-011A, BR-HW-012, BR-ATT-004A, BR-ATT-012 |
| `S10-D9` | A result can be closed only when the Student’s work is finished. | BR-RES-011 |

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
9. The system waits when unfinished checking or manual review could still change an official score.
10. Missing required work never creates an invented final score.
11. The homework–blitz difference is calculated correctly.
12. The correct average-or-blitz formula is applied.
13. A closed result records its calculation method and the rules it used; an open result always uses the current rules.
14. **Not completed** is used only for missing required work, not for waiting review, missing settings, or results that are not visible.
15. Calculated results can remain unreleased without becoming incomplete.
16. Historical records remain stable after deactivation, closure, or archiving.
17. Unauthorized direct links, filters, and record identifiers remain blocked.
18. The complete rules are understandable enough to convert into architecture, database constraints, API contracts, tests, and precise Codex tasks.

The main business-rule principle is:

> **TestLabUz must measure topic understanding through a controlled comparison of home performance and in-class blitz performance while preserving fairness, role boundaries, institution privacy, and clear result meaning.**
