# TestLabUz — User Flows

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

## 1. User Flows Overview

User flows in **TestLabUz** explain how each user moves through the system to complete their main tasks.

The purpose of this document is to describe the most important step-by-step actions for each role before technical architecture, database structure, API contracts, and development tasks are implemented.

The MVP supports five roles:

1. **Platform Owner / Super Admin**
2. **Institution Admin**
3. **Teacher**
4. **Student**
5. **Parent**

The Platform Owner / Super Admin manages the platform and institutions. The Institution Admin manages one institution, including users, groups, institution-level learning settings, and basic reports. The Teacher manages the learning-check process. The Student studies and completes assigned work. The Parent monitors permitted progress for connected children.

The main Topic-based learning-check flow is:

1. The Teacher creates a Topic for an assigned group.
2. The Teacher uploads learning materials.
3. The Teacher creates one or more Homework assignments.
4. The Teacher designates exactly one **whole-group Homework** as the official result-bearing Homework; selected-Student Homework remains practice-only.
5. The Student studies the materials.
6. The Student receives exactly **3 normal Homework attempts**.
7. The system records all valid Homework attempts and uses the **highest valid completed score** as the official Homework score after required checking is complete.
8. The Teacher creates one or more Blitz tasks.
9. The Teacher designates exactly one **whole-group Blitz** as the official result-bearing Blitz. When the first official task activates, the current eligible Topic-group cohort is snapshotted and reused for both official tasks.
10. During class, the Teacher activates the Blitz.
11. Blitz timing follows the institution's configured start mode: **synchronized** or **individual**.
12. The Student normally receives exactly **1 Blitz attempt**.
13. If a valid technical or other approved problem prevents proper completion, the Teacher may grant that Student exactly **1 additional Blitz attempt** and must record a reason.
14. If Blitz time expires, the system automatically finalizes saved answers; unanswered questions receive zero.
15. The system or Teacher completes required checking.
16. The system compares the official Homework and Blitz scores using unrounded values.
17. If `D <= T`, the system uses `(H + B) / 2`.
18. If `D > T`, the system uses the Blitz score.
19. The system assigns an understanding category using the derived integer `category_score`.
20. User-facing scores are displayed with one decimal place.
21. The Teacher reviews the result.
22. The Student sees the result according to the institution's Student release mode.
23. The Parent sees the result according to the institution's Parent visibility mode.
24. The Topic may later be closed or archived while historical attempts and results remain preserved.

The approved partial-credit behavior is:

- Single-choice: all-or-nothing.
- True / false: all-or-nothing.
- Multiple-choice: partial credit based on correctly selected options divided by total correct options, with Student selections capped at the number of correct options.
- Matching: partial credit per correctly matched pair.
- Ordering: partial credit per correctly positioned item.
- Fill-in-the-blank: partial credit per correctly completed blank.
- Open written and file-based answers: Teacher-assigned points.
- Short written answers: automatic when accepted-answer rules support it; otherwise Teacher review.

The platform hard maximum is **25 MB per learning-material file** and **15 MB per Student submission file**. An institution may configure lower limits.

Each institution uses one IANA timezone, such as `Asia/Tashkent`. Teachers enter educational deadlines and schedules in institution local time, while authoritative timestamps are stored and compared by the server as UTC instants. Device clocks and device timezones must not change deadlines or Blitz timing.

All flows must respect the multi-institution model and the approved device model:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

The MVP should stay simple and practical. AI-generated tasks, audio/video assignments, monetization, advanced analytics, communication tools, notifications, external integrations, and complex custom permissions remain future scope.

The main goal of this document is to make product behavior unambiguous enough to drive architecture, database, API, UI, testing, and precise Codex implementation tasks.

## 2. Platform Owner / Super Admin Flow

The **Platform Owner / Super Admin** flow explains how the highest-level user manages the whole **TestLabUz** platform.

This role is responsible for platform-level control. The Super Admin does not manage only one institution. Instead, this user manages all educational institutions that use the platform.

In the MVP version, the Super Admin flow should be simple and focused on basic platform management, institution control, platform monitoring, and support.

The Super Admin should use the desktop version of the platform because this role needs dashboards, tables, filters, institution management screens, and platform-level controls.

### Main Super Admin Flow

1. The Super Admin logs in to the platform.
2. The system checks the user role and permissions.
3. If the user is a Platform Owner / Super Admin, the system opens the Super Admin dashboard.
4. The Super Admin views general platform information.
5. The Super Admin manages educational institutions.
6. The Super Admin checks institution status and activity.
7. The Super Admin activates or deactivates institutions when needed.
8. The Super Admin supports Institution Admins when they have access or system issues.
9. The Super Admin reviews basic platform statistics.
10. The Super Admin manages basic global platform settings if needed.
11. The Super Admin logs out after completing platform management work.

### Super Admin Dashboard Flow

After login, the Super Admin should see the platform dashboard.

The dashboard should give a quick overview of the whole platform. It should help the Super Admin understand the current state of institutions and platform activity.

The dashboard may show:

- Total number of institutions
- Active institutions
- Inactive institutions
- Total users
- Active users
- Recent institution activity
- Institutions that may need attention
- Basic support or issue reports
- Basic platform statistics

From the dashboard, the Super Admin should be able to navigate to institution management, platform settings, support reports, and basic statistics.

### Institution Management Flow

The Super Admin should be able to manage institutions from the desktop interface.

The basic institution management flow is:

1. The Super Admin opens the institution list.
2. The system shows all institutions registered in the platform.
3. The Super Admin searches or filters institutions if needed.
4. The Super Admin opens one institution’s details.
5. The system shows basic institution information.
6. The Super Admin reviews the institution status, users, and activity overview.
7. The Super Admin edits basic institution information if needed.
8. The Super Admin activates or deactivates the institution if needed.

The institution list may include:

- Institution name
- Institution type
- Status
- Number of users
- Number of teachers
- Number of students
- Created date
- Last activity date
- Basic issue or support status

### Create Institution Flow

The Super Admin should be able to create a new institution inside **TestLabUz**.

The create institution flow is:

1. The Super Admin opens the institution list.
2. The Super Admin clicks “Create Institution”.
3. The system opens the create institution form.
4. The Super Admin enters basic institution information.
5. The Super Admin submits the form.
6. The system validates the information.
7. If the information is valid, the system creates the institution.
8. The system shows the new institution in the institution list.
9. The Super Admin may open the institution details to review it.

The create institution form may include:

- Institution name
- Institution type
- Contact information
- Status
- Basic description or notes if needed

In the MVP version, the create institution flow should stay simple. Advanced billing, subscription plans, storage limits, and license settings should not be included yet.

### Edit Institution Flow

The Super Admin should be able to edit basic institution information.

The edit institution flow is:

1. The Super Admin opens the institution list.
2. The Super Admin selects an institution.
3. The system opens the institution details page.
4. The Super Admin clicks “Edit”.
5. The system opens the edit institution form.
6. The Super Admin updates the necessary fields.
7. The Super Admin saves the changes.
8. The system validates the changes.
9. If the changes are valid, the system updates the institution information.
10. The system shows the updated institution details.

The Super Admin should only edit platform-level institution information. Daily learning data, student submissions, teacher-created assignments, blitz tasks, and class results should not normally be changed by the Super Admin.

### Activate Institution Flow

The Super Admin should be able to activate an institution.

The activate institution flow is:

1. The Super Admin opens the institution details page.
2. The Super Admin checks that the institution is inactive.
3. The Super Admin clicks “Activate”.
4. The system asks for confirmation.
5. The Super Admin confirms the action.
6. The system changes the institution status to active.
7. Users from that institution can use the platform again according to their roles and permissions.

This flow is useful when an institution was previously deactivated or temporarily blocked.

### Deactivate Institution Flow

The Super Admin should be able to deactivate an institution when needed.

The deactivate institution flow is:

1. The Super Admin opens the institution details page.
2. The Super Admin checks that the institution is active.
3. The Super Admin clicks “Deactivate”.
4. The system asks for confirmation.
5. The Super Admin confirms the action.
6. The system changes the institution status to inactive.
7. Users from that institution can no longer use the platform normally.
8. The system should block normal access for users inside the deactivated institution.

Institution deactivation should be used carefully. It may be needed for security, support, testing, policy, or future business reasons.

In the MVP version, the system should clearly show that the institution is inactive and that users from that institution are restricted.

### Institution Admin Support Flow

The Super Admin may support Institution Admins when they have access or configuration problems.

The support flow may be:

1. The Super Admin receives or sees a support issue.
2. The Super Admin opens the related institution.
3. The Super Admin reviews basic institution information.
4. The Super Admin checks the Institution Admin account status.
5. The Super Admin updates or supports the Institution Admin access if needed.
6. The Super Admin confirms that the institution can continue using the platform.

For example, the Super Admin may help if an Institution Admin loses access, the institution account is inactive, or the institution needs platform-level support.

In the MVP version, this support flow should stay basic. Advanced support ticket systems, detailed audit logs, support team roles, and internal support workflows can be added later.

### Platform Statistics Flow

The Super Admin should be able to view basic platform statistics.

The platform statistics flow is:

1. The Super Admin opens the platform dashboard or statistics page.
2. The system shows basic platform-level numbers.
3. The Super Admin reviews institution and user activity.
4. The Super Admin identifies institutions that may need attention.
5. The Super Admin takes action if needed.

Basic platform statistics may include:

- Total institutions
- Active institutions
- Inactive institutions
- Total users
- Active users
- Recently created institutions
- Institutions with low activity
- Institutions with support issues

In the MVP version, platform statistics should be simple. Advanced analytics, financial reports, deep usage reports, and detailed audit reports should be added later.

### Global Settings Flow

The Super Admin may manage basic global platform settings.

The global settings flow is:

1. The Super Admin opens platform settings.
2. The system shows global settings available in the MVP.
3. The Super Admin reviews or updates settings if needed.
4. The system validates the changes.
5. The system saves the updated settings.

Global settings should affect the whole platform, not only one institution.

In the MVP version, global settings should stay limited and simple. Institution-specific learning settings—such as category ranges, acceptable Homework–Blitz score-difference threshold, Blitz timer-start mode, result-release modes, institution timezone, and lower upload limits—belong to the Institution Admin flow. Homework and Blitz attempt counts are fixed by the approved MVP business rules.

### Access Restriction Flow

If a user who is not a Super Admin tries to open Super Admin pages, the system should block access.

The access restriction flow is:

1. A user tries to open a Super Admin page.
2. The system checks the user role and permissions.
3. If the user is not allowed, the system blocks the page.
4. The system shows a clear permission message.

Example messages:

- “You do not have permission to access this page.”
- “This section is available only for Platform Owner / Super Admin.”
- “You cannot access platform-level management.”

This protects platform-level data and prevents users from managing institutions without permission.

### Super Admin Flow Boundaries

The Super Admin can manage the platform, but should not normally interfere with daily learning activities inside institutions.

The Super Admin should not usually:

- Complete assignments for students
- Answer blitz tasks
- Change student submissions
- Change student scores
- Edit teacher-created assignments
- Edit teacher-created blitz tasks
- Manage daily classroom work
- Replace the Institution Admin or Teacher role

The Super Admin may access or support institution-level information only when there is a valid support, security, or system management reason.

### MVP Super Admin Flow Summary

In the MVP version, the Super Admin flow should include:

1. Login as Super Admin
2. View platform dashboard
3. View all institutions
4. Create institutions
5. View institution details
6. Edit basic institution information
7. Activate institutions
8. Deactivate institutions
9. View basic institution usage information
10. View basic platform statistics
11. Support Institution Admin access when needed
12. Manage basic global platform settings
13. Block unauthorized users from Super Admin pages

The main purpose of the Platform Owner / Super Admin flow is to keep the whole **TestLabUz** platform organized, controlled, and ready to support many educational institutions from the beginning.

## 3. Institution Admin Flow

The **Institution Admin** flow explains how an admin manages one educational institution inside **TestLabUz**.

This role does not manage the whole platform. The Institution Admin works only inside their own educational institution.

The main purpose of the Institution Admin flow is to organize users, groups, relationships, institution-level learning settings, and basic reporting so Teachers, Students, and Parents can use the system correctly.

In the MVP, the Institution Admin does **not** configure arbitrary Homework or Blitz attempt counts. The attempt model is fixed: Homework has 3 normal attempts; Blitz has 1 normal attempt plus at most one Student-specific Teacher-approved exception attempt.

The Institution Admin configures institution-level settings that may legitimately vary:

- Acceptable Homework–Blitz score-difference threshold
- Understanding-category numeric ranges
- Blitz timer-start mode: synchronized or individual
- Student result-release mode: automatic or manual Teacher release
- Parent result-visibility mode: with Student, manual Teacher release, or hidden
- Institution IANA timezone
- Lower upload limits within the platform maximums

The Institution Admin uses the desktop version because this role requires management screens, forms, settings, reports, tables, and filters.

### Main Institution Admin Flow

1. The Institution Admin logs in.
2. The system checks role, institution, account status, and permissions.
3. The system opens the Institution Admin dashboard.
4. The Institution Admin reviews institution structure and basic progress.
5. The Institution Admin manages Teacher, Student, and Parent accounts.
6. The Institution Admin creates and manages groups or classes.
7. The Institution Admin assigns Students to groups.
8. The Institution Admin assigns Teachers to groups.
9. The Institution Admin connects Parents to Students.
10. The Institution Admin configures understanding-category score ranges.
11. The Institution Admin configures the acceptable Homework–Blitz score-difference threshold.
12. The Institution Admin configures the Blitz timer-start mode.
13. The Institution Admin configures Student result-release mode.
14. The Institution Admin configures Parent result-visibility mode.
15. The Institution Admin configures the institution timezone.
16. The Institution Admin may configure lower learning-material and Student-submission file limits within platform maximums.
17. The Institution Admin views basic institution reports.
18. The Institution Admin logs out after completing management work.
### Institution Admin Dashboard Flow

After login, the Institution Admin should see the institution dashboard.

The dashboard should give a quick overview of the institution’s activity and structure. It should help the admin understand whether users, groups, and learning activity are organized correctly.

The dashboard may show:

- Total teachers
- Total students
- Total parents
- Total groups or classes
- Active groups
- Created topics
- Assigned homework tasks
- Assigned blitz tasks
- Homework completion overview
- Blitz completion overview
- Students or groups that may need attention
- Basic institution progress information

From the dashboard, the Institution Admin should be able to navigate to user management, group management, settings, and reports.

### Institution Profile Flow

The Institution Admin should be able to view and manage basic information about their own institution.

The institution profile flow is:

1. The Institution Admin opens the institution profile page.
2. The system shows basic institution information.
3. The Institution Admin reviews the information.
4. The Institution Admin clicks “Edit” if changes are needed.
5. The system opens the edit institution profile form.
6. The Institution Admin updates allowed fields.
7. The system validates the changes.
8. If the information is valid, the system saves the updated profile.

The institution profile may include:

- Institution name
- Institution type
- Contact information
- Address if needed
- Basic description
- Institution status

The Institution Admin should only manage information related to their own institution. They should not be able to edit another institution’s profile or platform-level settings.

### User Management Flow

The Institution Admin should be able to manage users inside their own institution.

The user management flow is:

1. The Institution Admin opens the user management section.
2. The system shows users that belong to the institution.
3. The Institution Admin filters users by role if needed.
4. The Institution Admin creates, views, edits, activates, or deactivates users.
5. The system saves changes only inside the current institution.

The Institution Admin can manage these user types:

- Teachers
- Students
- Parents

The Institution Admin should not be able to create or manage Platform Owner / Super Admin accounts.

### Teacher Account Flow

The Institution Admin should be able to create and manage teacher accounts.

The teacher account flow is:

1. The Institution Admin opens the teacher management section.
2. The system shows the list of teachers inside the institution.
3. The Institution Admin clicks “Create Teacher”.
4. The system opens the teacher creation form.
5. The Institution Admin enters teacher information.
6. The system validates the information.
7. If the information is valid, the system creates the teacher account.
8. The teacher appears in the teacher list.
9. The Institution Admin may edit, activate, or deactivate the teacher account later.

Teacher account information may include:

- Full name
- Contact information
- Login information
- Subject or specialization if needed
- Status
- Assigned groups if needed

A teacher can only work with groups and students assigned to them.

### Student Account Flow

The Institution Admin should be able to create and manage student accounts.

The student account flow is:

1. The Institution Admin opens the student management section.
2. The system shows the list of students inside the institution.
3. The Institution Admin clicks “Create Student”.
4. The system opens the student creation form.
5. The Institution Admin enters student information.
6. The system validates the information.
7. If the information is valid, the system creates the student account.
8. The student appears in the student list.
9. The Institution Admin assigns the student to one or more groups.
10. The Institution Admin may edit, activate, or deactivate the student account later.

Student account information may include:

- Full name
- Contact information
- Login information
- Group or class
- Status
- Parent connection if available

Students should only see topics, materials, assignments, blitz tasks, and results assigned to them.

### Parent Account Flow

The Institution Admin should be able to create and manage parent accounts.

The parent account flow is:

1. The Institution Admin opens the parent management section.
2. The system shows the list of parents inside the institution.
3. The Institution Admin clicks “Create Parent”.
4. The system opens the parent creation form.
5. The Institution Admin enters parent information.
6. The system validates the information.
7. If the information is valid, the system creates the parent account.
8. The parent appears in the parent list.
9. The Institution Admin connects the parent to one or more students.
10. The Institution Admin may edit, activate, or deactivate the parent account later.

Parent account information may include:

- Full name
- Contact information
- Login information
- Connected child or children
- Status

Parents should only be able to view the progress of their own connected child or children.

### Parent-Student Connection Flow

The Institution Admin should be able to connect parents to students.

The parent-student connection flow is:

1. The Institution Admin opens the parent or student profile.
2. The Institution Admin chooses the option to connect a parent and student.
3. The system shows users from the same institution.
4. The Institution Admin selects the correct parent and student.
5. The Institution Admin confirms the connection.
6. The system saves the parent-student relationship.
7. The parent can now view the child’s progress according to parent access rules.

The system should support these relationships:

- One parent can be connected to one student.
- One parent can be connected to multiple students.
- One student can be connected to one or more parents.

Parents must not be able to view students who are not connected to their account.

### Group or Class Management Flow

The Institution Admin should be able to create and manage groups or classes.

Groups are important because teachers, students, topics, assignments, blitz tasks, and reports are organized around them.

The group management flow is:

1. The Institution Admin opens the group management section.
2. The system shows all groups inside the institution.
3. The Institution Admin clicks “Create Group”.
4. The system opens the group creation form.
5. The Institution Admin enters group information.
6. The system validates the information.
7. If the information is valid, the system creates the group.
8. The Institution Admin assigns students and teachers to the group.
9. The Institution Admin may edit or archive the group later.

Group information may include:

- Group name
- Class or level
- Subject direction if needed
- Assigned teacher or teachers
- Assigned students
- Status
- Description if needed

A group should always belong to one institution.

### Assign Students to Group Flow

The Institution Admin should be able to assign students to groups.

The student-group assignment flow is:

1. The Institution Admin opens a group details page.
2. The Institution Admin clicks “Add Students”.
3. The system shows students from the same institution.
4. The Institution Admin selects one or more students.
5. The Institution Admin confirms the assignment.
6. The system adds the selected students to the group.
7. The students can now receive topics, materials, assignments, and blitz tasks assigned to that group.

The system should not allow students from another institution to be assigned to the group.

### Assign Teachers to Group Flow

The Institution Admin should be able to assign teachers to groups.

The teacher-group assignment flow is:

1. The Institution Admin opens a group details page.
2. The Institution Admin clicks “Assign Teacher”.
3. The system shows teachers from the same institution.
4. The Institution Admin selects one or more teachers.
5. The Institution Admin confirms the assignment.
6. The system connects the teacher to the group.
7. The teacher can now manage topics, materials, homework assignments, blitz tasks, and results for that group.

The system should not allow teachers from another institution to be assigned to the group.

### Assessment Category Settings Flow

The Institution Admin configures numeric score ranges for the first four understanding categories:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support

The **Not completed** category is non-numeric and is used only when required work can no longer validly be completed.

The flow is:

1. The Institution Admin opens assessment-category settings.
2. The system shows the four numeric categories and current ranges.
3. The Institution Admin edits the ranges.
4. The system validates that the ranges cover the full 0–100 scale without gaps or overlaps.
5. If valid, the system saves the institution settings.
6. New or explicitly recalculated open results use the applicable ranges.
7. Historical closed results retain the category-rule snapshot used when they were calculated.

Category assignment uses the derived integer `category_score`, not the one-decimal display value.
### Institution Learning Settings Flow

The Institution Admin configures institution-level learning settings. Attempt counts are not editable in the MVP.

#### Fixed Attempt Rules

- Homework: exactly **3 normal attempts**.
- Official Homework score: highest valid completed score from the three attempts.
- Blitz: exactly **1 normal attempt**.
- Teacher exception: at most **1 additional Blitz attempt for one Student**, with a required valid reason.
- The interrupted or invalid Blitz attempt remains in history and is excluded from official scoring under the approved exception.

#### Acceptable Score-Difference Setting

1. The Institution Admin opens assessment settings.
2. The admin enters the acceptable Homework–Blitz difference threshold `T`.
3. The system validates the value on the common 0–100 score scale.
4. The system saves the institution setting.
5. Final-result calculation later uses `D = |H - B|`.
6. `D <= T` means consistent; `D > T` means inconsistent.

#### Blitz Timer-Start Mode Setting

The Institution Admin selects one mode:

- **Synchronized** — Teacher activation starts the timer for all assigned Students.
- **Individual** — Teacher activation makes the Blitz available, but each Student's timer begins when that Student starts.

The Teacher still chooses the duration of each Blitz.

#### Student Result-Release Setting

The Institution Admin selects:

- **Automatic** — a fully calculated result becomes visible to the Student automatically.
- **Manual Teacher release** — a fully calculated result remains hidden until the Teacher releases it.

Calculation status and visibility remain separate.

#### Parent Result-Visibility Setting

The Institution Admin selects:

- **With Student** — Parent visibility begins after Student release.
- **Manual Teacher release** — Parent visibility requires a separate Teacher release after Student release.
- **Hidden** — the result remains unavailable to Parents.

A Parent must never receive the result before the Student result has been released.

#### Institution Timezone Setting

1. The Institution Admin chooses an IANA timezone, such as `Asia/Tashkent`.
2. Teachers enter educational deadlines and schedules in institution local time.
3. The backend converts and compares authoritative instants in UTC.
4. Device clocks and device timezones do not change deadlines or Blitz timing.
5. Changing the institution timezone later must not change historical absolute timestamps.

#### Upload-Limit Setting

Platform hard maximums are:

- Learning materials: **25 MB per file**
- Student submission files: **15 MB per file**

The Institution Admin may configure smaller institution limits but cannot exceed the platform maximums.
### Institution Reports Flow

The Institution Admin should be able to view basic reports for their own institution.

The institution reports flow is:

1. The Institution Admin opens the reports section.
2. The system shows basic institution-level reports.
3. The Institution Admin filters reports if needed.
4. The Institution Admin reviews group activity, student progress, topic progress, and completion information.
5. The Institution Admin identifies groups, students, or topics that may need attention.

Reports may include:

- Total users
- Active teachers
- Active students
- Active groups
- Topic activity
- Homework completion overview
- Blitz completion overview
- Understanding category distribution
- Students who need revision
- Students who need teacher support
- Groups with low activity
- Submissions waiting for teacher review

The Institution Admin should use reports for monitoring and support. They should not normally change student answers, manually manipulate scores, or replace the teacher’s checking role.

### Access Restriction Flow

If a user tries to access Institution Admin pages without permission, the system should block access.

The access restriction flow is:

1. A user tries to open an Institution Admin page.
2. The system checks the user role, institution, and permissions.
3. If the user is not allowed, the system blocks the page.
4. The system shows a clear permission message.

Example messages:

- “You do not have permission to access this page.”
- “This section is available only for Institution Admins.”
- “You cannot access data from another institution.”
- “You cannot manage this institution.”

This protects institution-level data and prevents unauthorized management actions.

### Institution Admin Flow Boundaries

The Institution Admin manages the institution structure, but should not normally replace the teacher or student role.

The Institution Admin should not usually:

- Complete assignments for students
- Answer blitz tasks for students
- Change student submissions
- Change student answers
- Manually manipulate scores
- Create daily learning content instead of teachers
- Check teacher-created assignments unless future rules allow it
- Access another institution’s data
- Manage platform-level institutions or global platform settings

The Institution Admin may view progress and reports for management purposes, but daily learning work should remain mainly under the Teacher role.

### MVP Institution Admin Flow Summary

In the MVP, the Institution Admin flow includes:

1. Login as Institution Admin.
2. View institution dashboard.
3. View and edit allowed institution profile fields.
4. Manage Teacher accounts.
5. Manage Student accounts.
6. Manage Parent accounts.
7. Activate and deactivate institution users.
8. Create and manage groups or classes.
9. Assign Students to groups.
10. Assign Teachers to groups.
11. Connect Parents to Students.
12. Configure understanding-category score ranges.
13. Configure acceptable Homework–Blitz score-difference threshold.
14. Configure synchronized or individual Blitz timer-start mode.
15. Configure automatic or manual Student result release.
16. Configure Parent visibility as with Student, manual Teacher release, or hidden.
17. Configure institution IANA timezone.
18. Configure lower upload limits within platform maximums.
19. View basic institution reports.
20. Identify groups or Students that may need attention.
21. Block unauthorized Institution Admin access.
22. Block cross-institution access.

The Institution Admin organizes the institution but does not replace the Teacher's educational role or alter the fixed MVP attempt counts.

## 4. Teacher Flow

The **Teacher** flow explains how teachers use **TestLabUz** to manage the main learning-check process.

The Teacher is the main educational user in the system. Teachers create topics, upload learning materials, create homework assignments, create blitz tasks, start blitz tasks during class, check student submissions, and review student understanding results.

A teacher works inside one educational institution and can only manage the groups, students, topics, assignments, blitz tasks, and results assigned to them.

In the MVP version, the Teacher flow should focus on the complete topic-based learning process: topic creation, material upload, homework assignment, blitz verification, result comparison, and understanding assessment.

Teachers should have both desktop and mobile access. The desktop version should be used for larger work such as creating topics, uploading files, building assignments, checking answers, and reviewing detailed reports. The mobile version should support quick actions such as viewing groups, starting blitz tasks, monitoring class progress, and checking basic results.

### Main Teacher Flow

1. The Teacher logs in.
2. The system checks role, institution, assigned groups, account status, and permissions.
3. The system opens the Teacher dashboard.
4. The Teacher views assigned groups, active Topics, pending reviews, and Students needing attention.
5. The Teacher creates a Topic for an assigned group.
6. The Teacher uploads learning materials.
7. The Teacher creates one or more Homework assignments.
8. Before Student attempts begin, the Teacher designates exactly one Homework as the official result-bearing Homework for the Topic.
9. Students study the materials and receive exactly 3 normal Homework attempts.
10. The system selects the highest valid completed Homework score as official after required checking.
11. The Teacher creates one or more Blitz tasks for the same Topic.
12. Before Student attempts begin, the Teacher designates exactly one Blitz as the official result-bearing Blitz for the Topic.
13. The Teacher configures the whole-Blitz duration.
14. During class, the Teacher activates the Blitz.
15. The system applies the institution's synchronized or individual timer-start mode.
16. Students normally receive one Blitz attempt.
17. The Teacher monitors Blitz progress and may grant one Student-specific additional Blitz attempt for a valid reason when required.
18. At timeout, the system automatically finalizes saved answers and gives zero for unanswered questions.
19. The Teacher checks answers requiring manual review.
20. The system records official Homework and Blitz scores.
21. The system compares both official scores using unrounded values and calculates the final Topic result.
22. The system assigns the understanding category using the derived integer `category_score`.
23. The Teacher reviews results and identifies Students needing revision or support.
24. When institution policy requires it, the Teacher releases the result to the Student and/or Parent according to the approved release hierarchy.
25. The Teacher logs out after completing teaching work.
### Teacher Dashboard Flow

After login, the teacher should see the Teacher dashboard.

The dashboard should help the teacher quickly understand what needs attention.

The dashboard may show:

- Assigned groups
- Assigned students
- Active topics
- Draft topics
- Active homework assignments
- Upcoming or active blitz tasks
- Homework completion status
- Blitz completion status
- Submissions waiting for manual checking
- Students who did not complete tasks
- Students who need revision
- Students who need teacher support
- Students with large homework/blitz score differences

From the dashboard, the teacher should be able to open groups, topics, assignments, blitz tasks, submissions, and reports.

### Assigned Groups Flow

The teacher should be able to view only the groups assigned to them.

The assigned groups flow is:

1. The teacher opens the groups section.
2. The system shows only groups assigned to that teacher.
3. The teacher selects a group.
4. The system opens the group details page.
5. The teacher views students, topics, assignments, blitz tasks, and progress for that group.

The teacher should not be able to access unrelated groups unless the Institution Admin assigns them to those groups.

### Assigned Students Flow

The teacher should be able to view students inside their assigned groups.

The assigned students flow is:

1. The teacher opens a group details page.
2. The system shows students assigned to that group.
3. The teacher selects a student if needed.
4. The system shows the student’s topic progress, homework status, blitz results, final results, and understanding categories.
5. The teacher identifies whether the student needs revision or teacher support.

The teacher should not be able to view students from another institution or unrelated groups.

### Topic Creation Flow

The teacher should be able to create a topic for an assigned group.

The topic creation flow is:

1. The teacher opens the topic section or a group details page.
2. The teacher clicks “Create Topic”.
3. The system opens the topic creation form.
4. The teacher enters topic information.
5. The teacher assigns the topic to a group or class.
6. The teacher saves the topic as a draft or makes it active.
7. The system validates the information.
8. If the information is valid, the system creates the topic.

Topic information may include:

- Topic title
- Topic description
- Subject
- Group or class
- Lesson date if needed
- Instructions for students
- Topic status

The topic should belong to the correct institution, teacher, and group.

### Learning Material Upload Flow

After creating a Topic, the Teacher may upload one or more learning materials.

The flow is:

1. The Teacher opens the Topic details page.
2. The Teacher clicks **Upload Material**.
3. The system shows the supported formats and effective file-size limit.
4. The Teacher selects a PDF, DOCX, PPT, or PPTX file.
5. The client may pre-check type and size for usability.
6. The backend authoritatively validates type, size, institution, Topic, and permission.
7. The platform hard maximum is **25 MB per file**; a lower institution limit may apply.
8. If valid, the system uploads and connects the file to the Topic.
9. Assigned Students can open or download it when the Topic is accessible.
10. An oversized, unsupported, or failed upload is rejected and does not create a valid material record.

The Teacher may view, replace, update, or remove materials for their own Topics when lifecycle rules allow it.
### Homework Assignment Creation Flow

The Teacher creates Homework connected to a Topic.

1. The Teacher opens a Topic.
2. The Teacher clicks **Create Homework Assignment**.
3. The system opens the Homework builder.
4. The Teacher enters title, instructions, recipients, questions, answer data, and points.
5. The Teacher may add an institution-local deadline.
6. The system clearly shows the fixed rule: **3 normal attempts per Student**.
7. The Teacher does not configure the attempt count.
8. The Teacher saves the Homework as draft or activates it when valid.
9. If the Topic contains multiple Homework tasks, the Teacher designates exactly one as the official result-bearing Homework before Student attempts begin.
10. The system validates that the designated Homework belongs to the same Topic and authorized scope.
11. Once Students begin attempts on the designated result-bearing Homework, that designation cannot be replaced in a way that changes existing result meaning.
12. Assigned Students can access active Homework.

Homework information may include:

- Title and description
- Topic
- Group or selected Students
- Instructions
- Questions and question types
- Answer options and correct-answer data where applicable
- Points or score rules
- Fixed 3-attempt rule
- Deadline if applicable
- Lifecycle status
- Result-bearing designation
### Assignment Type Flow

The Teacher may build Homework and Blitz tasks using the nine approved question types:

1. Single-choice
2. Multiple-choice
3. True / false
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching
8. Ordering
9. Fill-in-the-blank

The flow is:

1. The Teacher selects a question type.
2. The system shows the correct builder.
3. The Teacher enters the prompt and required configuration.
4. The Teacher defines answer options/correct-answer data where automatic checking is supported.
5. The Teacher assigns the question point value.
6. The system later applies the approved scoring rule:
   - Single-choice: all-or-nothing.
   - True / false: all-or-nothing.
   - Multiple-choice: partial credit based on correctly selected options divided by total correct options, with Student selections capped at the number of correct options.
   - Matching: partial credit per correctly matched pair.
   - Ordering: partial credit per correctly positioned item.
   - Fill-in-the-blank: partial credit per correctly completed blank.
   - Short written answer: automatic only when accepted-answer rules allow; otherwise manual.
   - Open written answer: manual Teacher points.
   - File-based assignment: manual Teacher points.
7. The Teacher saves the question and continues until the task is ready.

The Teacher may score manual answers but must not rewrite Student-submitted content.
### Homework Progress Flow

After students receive homework, the teacher should be able to monitor progress.

The homework progress flow is:

1. The teacher opens the assignment progress page.
2. The system shows students assigned to the homework.
3. The teacher reviews each student’s status.
4. The teacher identifies students who have not started, are in progress, submitted, are waiting for review, or did not complete the task.
5. The teacher takes action if needed.

Homework statuses may include:

- Not started
- In progress
- Submitted
- Waiting for teacher review
- Checked
- Not completed
- Closed

This flow helps the teacher understand whether students are completing homework before the blitz task.

### Blitz Task Creation Flow

The Teacher creates a manual Blitz for an assigned Topic.

1. The Teacher opens the Topic.
2. The Teacher clicks **Create Blitz Task**.
3. The system opens the Blitz builder.
4. The Teacher enters title and instructions.
5. The Teacher adds short, focused questions.
6. The Teacher defines answer options and correct-answer data where applicable.
7. The Teacher defines points or score rules.
8. The Teacher sets one **whole-Blitz duration**.
9. The Teacher does not configure arbitrary attempt counts; the normal limit is fixed at one.
10. The Teacher saves the Blitz as draft or scheduled.
11. If the Topic contains multiple Blitz tasks, the Teacher designates exactly one as the official result-bearing Blitz before Student attempts begin.
12. The system validates the task and designation.
13. Once Students begin attempts on the designated result-bearing Blitz, that designation cannot be replaced in a way that changes existing result meaning.

The institution's timer-start mode—not the Teacher—determines whether timing starts synchronously at activation or individually when each Student starts.
### Blitz Activation Flow

The Teacher activates the prepared Blitz during class.

1. The Teacher opens the Blitz.
2. The system shows the Topic, recipients, questions, duration, fixed normal-attempt rule, and institution timer-start mode.
3. The Teacher clicks **Start / Activate**.
4. The system validates permissions and task state.
5. The Teacher confirms if required.
6. The system records the authoritative server activation time and changes the Blitz lifecycle to Active.
7. Assigned Students may now access the Blitz.

If the institution uses **synchronized start**:

- The countdown starts for all assigned Students at Teacher activation.
- A Student opening later receives only the remaining time.

If the institution uses **individual start**:

- Teacher activation makes the Blitz available.
- Each Student's timer starts when that Student starts the attempt.
- Each Student receives the full configured duration.

Device clocks cannot extend the available time.
### Blitz Monitoring Flow

During class, the Teacher monitors Student participation.

1. The Teacher opens the active Blitz monitoring screen.
2. The system shows assigned Students and their current state.
3. The Teacher can see who has not started, started, is in progress, submitted, was auto-finalized at timeout, is waiting for manual review, or did not complete validly.
4. The system shows timing information based on authoritative server time.
5. If a Student reports a valid technical or other approved problem, the Teacher reviews the case.
6. If justified, the Teacher grants **one additional Blitz attempt to that specific Student** and enters a required reason.
7. The original interrupted/invalid attempt remains in history and is excluded from official scoring under the approved exception.
8. No Student can receive more than one such additional Blitz opportunity in the MVP.
9. The exception does not change the attempt availability for other Students.

The monitoring screen may show:

- Student name
- Access/start status
- In-progress/submission/timeout status
- Remaining or elapsed time
- Attempt number
- Normal or exception-attempt indicator
- Technical-exception reason/status
- Review status
- Score when available

The Teacher cannot change a Student's live answers through monitoring.
### Manual Checking Flow

Some Homework and Blitz answers require Teacher review.

1. The Teacher opens submissions waiting for review.
2. The system shows the immutable Student answer or protected uploaded file.
3. The Teacher reviews the answer.
4. The Teacher assigns points within the allowed question maximum.
5. The Teacher may add feedback.
6. The Teacher saves the review.
7. The system updates the submission/review state.
8. When all required manual review for an attempt is complete, the attempt score becomes valid for official-score selection.
9. If the Teacher corrects an underlying manual score before the Topic result is closed, the system recalculates the dependent official task score and Topic result.
10. The Teacher may not directly override the final Topic formula.

Manual review is normally required for open written answers and file-based answers, and may be required for short written answers that need judgment.
### Result Review Flow

After official Homework and Blitz scores are ready, the Teacher reviews the Topic result.

1. The system identifies the designated official Homework and Blitz for the Topic.
2. The system identifies the official Homework score as the highest valid completed score from the Student's three Homework attempts.
3. The system identifies the official valid Blitz attempt, including the approved exception attempt when one exists.
4. The system calculates `D = |H - B|` using unrounded values.
5. The system compares `D` with the institution threshold `T`.
6. If `D <= T`, the final score is `(H + B) / 2`.
7. If `D > T`, the final score is `B`.
8. The system assigns the understanding category from the derived integer `category_score`.
9. The UI displays scores with one decimal place.
10. The Teacher reviews the result, consistency state, manual-review state, attempts, and feedback.
11. If Student release mode is `manual_teacher`, the Teacher may release the fully calculated result to the Student.
12. If Parent mode is `manual_teacher`, the Teacher may release it to the Parent only after Student release.
13. If Parent mode is `with_student`, Parent visibility follows Student release automatically.
14. If Parent mode is `hidden`, the Parent does not receive the result.

The Teacher cannot use the release action to change the calculated score or category.
### Understanding Category Flow

The teacher should be able to view students by understanding category.

The MVP understanding categories are:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The understanding category flow is:

1. The teacher opens the topic result page or report page.
2. The teacher selects an understanding category filter.
3. The system shows students in that category.
4. The teacher reviews which students need attention.
5. The teacher decides what to do next.

For example, students in “Needs revision” may need more practice. Students in “Needs teacher support” may need direct explanation from the teacher.

### Student Support Flow

The teacher should use results to decide how to support students.

The student support flow is:

1. The teacher reviews topic results.
2. The teacher identifies students with weak final results.
3. The teacher checks whether the student completed homework and blitz tasks.
4. The teacher checks whether there is a big homework/blitz score difference.
5. The teacher reviews teacher feedback or manual answers if available.
6. The teacher decides whether the student needs revision, extra practice, or direct teacher support.

This flow is important because the goal of **TestLabUz** is not only to score students, but to help teachers understand what support each student needs.

### Teacher Reports Flow

The teacher should be able to view progress reports for assigned groups, topics, and students.

The teacher reports flow is:

1. The teacher opens the reports section.
2. The system shows only data from assigned groups and students.
3. The teacher selects a report type.
4. The teacher filters by group, topic, student, completion status, or understanding category.
5. The teacher reviews the report.
6. The teacher identifies students or topics that need attention.

Teacher reports may include:

- Topic progress
- Group progress
- Individual student progress
- Homework completion
- Blitz completion
- Final results
- Understanding categories
- Students waiting for manual review
- Students who did not complete tasks
- Students with large homework/blitz score differences

### Teacher Mobile Flow

Teachers may use mobile for quick classroom actions.

A typical mobile flow is:

1. Login as Teacher.
2. View assigned groups and active Topics.
3. View Homework completion and pending review status.
4. Activate a prepared Blitz.
5. Monitor synchronized or individual Blitz progress.
6. View Students affected by timeout or technical problems.
7. Grant one Student-specific additional Blitz attempt when a valid reason exists.
8. View basic result summaries.
9. Release Student or Parent results when the institution policy requires Teacher action.
10. Identify Students needing revision or support.

The mobile interface does not replace the full desktop authoring/checking experience and does not change permissions.
### Access Restriction Flow

If a teacher tries to access data outside their allowed scope, the system should block access.

The access restriction flow is:

1. The teacher tries to open a restricted page or record.
2. The system checks the teacher’s institution, assigned groups, and permissions.
3. If the teacher is not allowed, the system blocks the action.
4. The system shows a clear permission message.

Example messages:

- “You do not have permission to access this page.”
- “This group is not assigned to you.”
- “You cannot access data from another institution.”
- “You cannot edit this topic.”
- “You cannot manage this student.”

This protects institution data, student privacy, and teacher access boundaries.

### Teacher Flow Boundaries

The Teacher role focuses on learning and assessment, not institution administration.

Teachers must not:

- Manage platform institutions or global platform settings.
- Create or manage Super Admin or Institution Admin accounts.
- Access another institution or unrelated groups.
- Change institution-wide learning settings.
- Configure arbitrary Homework or Blitz attempt counts.
- Give more than one approved additional Blitz attempt to one Student.
- Complete Homework or Blitz on behalf of Students.
- Rewrite Student-submitted answers.
- Replace the designated result-bearing Homework/Blitz after Student attempts begin in a way that changes historical meaning.
- Directly override the final Topic score or category outside the approved calculation.
- Release a Parent result before Student release.

Teachers may set Homework deadlines and whole-Blitz duration because those are task-level responsibilities explicitly allowed by the MVP.
### MVP Teacher Flow Summary

The MVP Teacher flow includes:

1. Login and view Teacher dashboard.
2. View assigned groups and Students.
3. Create and manage own Topics.
4. Upload learning materials up to the effective 25 MB limit.
5. Create Homework using the nine question types.
6. Apply the fixed 3-attempt Homework rule.
7. Set Homework deadline when needed.
8. Designate one official result-bearing Homework before attempts begin.
9. Monitor Homework progress.
10. Create manual Blitz tasks.
11. Set whole-Blitz duration.
12. Designate one official result-bearing Blitz before attempts begin.
13. Activate Blitz during class.
14. Apply the institution's synchronized or individual start mode.
15. Monitor Blitz progress.
16. Grant one Student-specific additional Blitz attempt for a valid reason.
17. Auto-finalize Student Blitz work at timeout.
18. Review manual answers.
19. Apply approved partial-credit scoring.
20. View official Homework and Blitz scores.
21. Review unrounded-calculation results shown with one-decimal display.
22. View understanding categories.
23. Release Student results when `manual_teacher` mode requires it.
24. Release Parent results when `manual_teacher` mode requires it and Student release already occurred.
25. View Topic, group, and Student progress.
26. Identify Students needing revision or Teacher support.
27. Use desktop for detailed work and mobile for quick classroom actions.
28. Remain inside assigned institution/group scope.

## 5. Student Flow

The **Student** flow explains how students use **TestLabUz** to study learning materials, complete homework assignments, answer blitz tasks during class, and view their own learning progress.

The Student is the main learning user in the system. Students do not manage users, create official topics, upload official learning materials, create assignments, or check results. Their main responsibility is to study assigned topics and complete the tasks given by their teachers.

A student belongs to one educational institution and may be assigned to one or more groups or classes inside that institution. A student should only see topics, materials, homework assignments, blitz tasks, submissions, scores, and results that are assigned to them.

In the MVP version, the Student flow should focus on the full learning process from the student side: open topic, study materials, complete homework, join active blitz task, submit answers, and view personal results if allowed.

Students should have both desktop and mobile access. The desktop version should be useful for studying larger materials, writing longer answers, uploading files, and completing more detailed assignments. The mobile version should be useful for quick study, simple tasks, and blitz participation during class.

### Main Student Flow

1. The Student logs in.
2. The system checks role, institution, group assignment, account status, and permissions.
3. The Student dashboard opens.
4. The Student views assigned Topics, active Homework, Teacher-activated Blitz tasks, and progress.
5. The Student opens an assigned Topic and studies learning materials.
6. The Student opens the assigned Homework and sees instructions, deadline, and the fixed **3 normal attempts**.
7. The Student completes one or more Homework attempts.
8. Each submitted attempt is stored separately.
9. After required checking, the system uses the **highest valid completed Homework score** as official.
10. During class, the Student can access the Blitz only after Teacher activation.
11. In synchronized mode, the Student receives the time remaining from Teacher activation.
12. In individual mode, the Student receives the full duration starting when that Student starts.
13. The Student normally has **1 Blitz attempt**.
14. The Student answers while the authoritative timer is running.
15. If time reaches zero before explicit submission, the system automatically finalizes saved answers; unanswered questions receive zero.
16. If a valid technical or other approved issue prevented proper completion, the Teacher may grant exactly one additional Blitz attempt.
17. Automatic checking and Teacher review complete as required.
18. The system calculates the Topic result.
19. The Student sees the result only after release according to institution policy.
20. The Student logs out after learning work is complete.
### Student Dashboard Flow

After login, the student should see the Student dashboard.

The dashboard should help the student understand what they need to do next.

The dashboard may show:

- Assigned topics
- New learning materials
- Active homework assignments
- Homework deadlines if available
- Homework attempts remaining
- Active blitz tasks
- Completed tasks
- Tasks waiting for teacher review
- Scores if released
- Understanding categories if released
- Topics that need revision
- Topics that need teacher support

From the dashboard, the student should be able to open topics, learning materials, homework assignments, active blitz tasks, and personal progress.

### Assigned Topics Flow

The student should be able to view only topics assigned to their group or directly assigned to them.

The assigned topics flow is:

1. The student opens the topics section.
2. The system shows topics assigned to the student.
3. The student selects a topic.
4. The system opens the topic details page.
5. The student views topic information, materials, homework assignment, blitz status, and result status.

Topic information may include:

- Topic title
- Topic description
- Subject
- Teacher
- Group or class
- Student instructions
- Learning materials
- Homework assignment status
- Blitz task status
- Final result status

The student should not be able to access topics from another institution, unrelated group, or another student’s private assignment scope.

### Learning Material Study Flow

The student should be able to open and study learning materials uploaded by the teacher.

The learning material study flow is:

1. The student opens an assigned topic.
2. The system shows learning materials connected to that topic.
3. The student selects a material.
4. The system opens or downloads the material according to platform design.
5. The student studies the material independently.
6. The student returns to the topic page to complete the homework assignment.

In the MVP version, supported learning material formats are:

- PDF
- DOCX
- PPT
- PPTX

Learning materials help the student repeat the lesson, review the teacher’s explanation, and prepare for homework and blitz tasks.

### Homework Assignment Flow

The Student completes assigned Homework using the fixed MVP attempt model.

1. The Student opens an assigned Topic.
2. The Student selects an active Homework.
3. The system shows instructions, question types, points, deadline if present, and **3 total normal attempts**.
4. The system shows the current attempt number and remaining attempts.
5. The Student starts an available attempt.
6. The Student answers the questions.
7. For file-based questions, the Student uploads a supported file within the effective **15 MB** limit.
8. The Student reviews answers if allowed.
9. The Student submits.
10. The backend validates assignment, deadline, attempt availability, institution scope, answers, and files.
11. A valid submitted attempt is locked and stored separately.
12. If attempts remain and the Homework is still active and before deadline, the Student may start another attempt.
13. After three normal attempts, no fourth normal attempt is allowed.
14. The system automatically checks objective parts and waits for Teacher review where required.
15. The highest valid completed Homework score becomes official after required checking.

Submission/review states remain separate from Homework lifecycle status.
### Assignment Type Answering Flow

The student should be able to answer all assignment types supported in the MVP.

The MVP assignment types are:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

The assignment type answering flow is:

1. The student opens a question.
2. The system shows the correct answer interface for that question type.
3. The student enters or selects an answer.
4. The system saves the answer during the attempt if supported.
5. The student continues to the next question.
6. The student submits the assignment when finished.
7. The system records the submitted answers.

For test questions, the student selects answer options.  
For written questions, the student types an answer.  
For file-based assignments, the student uploads a file.  
For matching tasks, the student matches related items.  
For ordering tasks, the student puts items in the correct order.  
For fill-in-the-blank tasks, the student fills missing words, numbers, or values.

### File-Based Assignment Flow

For file-based assignments, the Student uploads a file as the answer.

1. The Student opens the file-based question.
2. The system shows supported formats and the effective file-size limit.
3. The Student selects a PDF, DOCX, PPT, or PPTX file.
4. The client may pre-check file type and size.
5. The backend authoritatively validates type, size, ownership, assignment, attempt, and institution scope.
6. The platform hard maximum is **15 MB per Student submission file**; a lower institution limit may apply.
7. If valid, the file is attached to that Student's specific attempt.
8. The Student submits the attempt.
9. A failed, unsupported, or oversized upload is not treated as a valid answer.
10. The Teacher later reviews and scores the file-based answer.

The system should show a clear validation message when upload requirements are not met.
### Attempt Flow

The Student attempt flow is fixed by task type.

#### Homework

1. The Student opens the Homework.
2. The system shows **3 total normal attempts**.
3. The system shows the current attempt and remaining attempts.
4. The Student submits an attempt.
5. The system stores that attempt without overwriting earlier attempts.
6. If another normal attempt remains and deadline/status rules allow it, the Student may try again.
7. After attempt 3, the system blocks a fourth normal Homework attempt.
8. The official Homework score becomes the highest valid completed score after required checking.

#### Blitz

1. The Student normally has exactly **1 Blitz attempt**.
2. The Student cannot create a second attempt themselves.
3. If a valid technical or other approved issue prevents proper completion, an authorized Teacher may grant exactly **1 additional Blitz attempt**.
4. The Teacher must record a reason.
5. The original interrupted/invalid attempt remains in history and is excluded from official scoring under the approved exception.
6. No third Blitz attempt is available in the MVP.

Attempt availability is also blocked by assignment, deadline, lifecycle, authorization, and authoritative timing rules.
### Blitz Task Access Flow

The Student may access a Blitz only after Teacher activation and only if assigned.

1. The Student opens the dashboard or Topic during class.
2. The system checks whether the Blitz is active for that Student.
3. The system checks the institution timer-start mode.
4. If the task is not active/assigned, answering is blocked.
5. If active, the Student opens the Blitz.
6. The system shows instructions, whole-Blitz duration/remaining time, and normal attempt availability.
7. In **synchronized mode**, the effective deadline was created from Teacher activation and the configured duration.
8. In **individual mode**, the Student presses Start and receives the full duration from the server-recorded attempt start time.
9. The Student begins answering.

Draft, scheduled-before-activation, closed, archived, unrelated, or expired Blitz tasks cannot be answered.
### Blitz Answering Flow

The Student completes the Blitz during class.

1. The Student opens the active Blitz.
2. The system shows the authoritative remaining time.
3. The Student answers questions.
4. Saved answers received before the deadline remain eligible for scoring.
5. The Student may explicitly submit before time expires.
6. On explicit submission, the attempt is finalized and cannot be edited.
7. If time reaches `00:00` first, the backend stops accepting changes and automatically finalizes the saved attempt.
8. Answered questions are evaluated normally.
9. Unanswered questions receive zero points.
10. Answers requiring Teacher judgment remain waiting for Teacher review rather than being automatically marked wrong.
11. Writes received after the authoritative deadline are rejected.
12. The system updates the Student's submission/review state.

The device clock or timezone cannot create extra time.
### Automatic and Manual Checking Flow

After Homework or Blitz finalization, the system and Teacher complete checking.

1. The system identifies the question type.
2. Single-choice and true/false questions are scored all-or-nothing.
3. Multiple-choice receives partial credit based on correctly selected options divided by total correct options, with Student selections capped at the number of correct options.
4. Matching receives partial credit per correctly matched pair.
5. Ordering receives partial credit per correctly positioned item.
6. Fill-in-the-blank receives partial credit per correctly completed blank.
7. Short written answers may be auto-checked when accepted-answer rules allow; otherwise they wait for Teacher review.
8. Open written and file-based answers wait for Teacher review.
9. The Teacher assigns allowed points and feedback where manual review is required.
10. The Teacher cannot rewrite the Student's submitted answer.
11. The attempt score becomes complete only after all required review is finished.
12. The Student sees the score/result only according to release policy.
### Result Viewing Flow

A calculated result is not automatically visible in every institution.

1. The Student opens the Topic or personal progress page.
2. The system checks the Topic result calculation state.
3. The system separately checks Student visibility.
4. If Student release mode is **automatic**, a fully calculated result becomes visible automatically.
5. If Student release mode is **manual Teacher release**, the result remains hidden until the Teacher releases it.
6. When visible, the Student sees the official Homework score, official Blitz score, final Topic score, understanding category, completion status, and allowed feedback.
7. User-facing numeric scores are shown with **one decimal place**.
8. A calculated but unreleased result is not incomplete; it is simply hidden from the Student.

The Student can view only their own result.
### Understanding Category Flow

The student should be able to understand their learning result through clear categories if results are released.

The MVP understanding categories are:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The understanding category flow is:

1. The student opens personal results.
2. The system shows the final understanding category for each topic.
3. The student reads the category meaning if needed.
4. The student identifies whether the topic is successfully completed or needs more work.

This helps the student understand progress more clearly than a score alone.

For example, “Needs revision” means the student should study the topic again. “Needs teacher support” means the student may need direct explanation or help from the teacher.

### Personal Progress Flow

The student should be able to view personal learning progress.

The personal progress flow is:

1. The student opens the progress section.
2. The system shows only the student’s own learning data.
3. The student views assigned topics, task statuses, scores, and categories.
4. The student filters or reviews topics if needed.
5. The student identifies completed topics and topics that need revision.

Personal progress may show:

- Assigned topics
- Completed topics
- Homework completion status
- Blitz completion status
- Scores if released
- Final results if released
- Understanding categories
- Teacher feedback if available
- Topics needing revision
- Topics needing teacher support

The purpose of this flow is to help the student take responsibility for their own learning.

### Student Desktop Flow

Students should have desktop access for tasks that need more screen space and more comfortable interaction.

The student desktop flow may include:

1. The student logs in from desktop.
2. The system opens the Student dashboard.
3. The student views assigned topics.
4. The student opens larger learning materials.
5. The student completes written assignments.
6. The student uploads files for file-based assignments.
7. The student reviews personal progress.
8. The student views results if released.

The desktop version is especially useful for:

- Reading documents
- Viewing presentations
- Writing longer answers
- Uploading files
- Completing detailed assignments
- Reviewing progress carefully

### Student Mobile Flow

Students should also have mobile access for quick learning actions and blitz participation.

The student mobile flow may include:

1. The student logs in from mobile.
2. The system opens the Student dashboard.
3. The student views assigned topics.
4. The student opens learning materials if supported on mobile.
5. The student completes simple homework tasks.
6. The student joins active blitz tasks during class.
7. The Student answers questions within the whole-Blitz timer.
8. The student submits blitz answers.
9. The student views personal progress and results if released.

The mobile version is especially useful for:

- Quick access to topics
- Simple tests
- True / false questions
- Matching tasks
- Fill-in-the-blank tasks
- Blitz participation during class
- Checking completion status
- Viewing scores and understanding categories

### Access Restriction Flow

If a student tries to access data outside their allowed scope, the system should block access.

The access restriction flow is:

1. The student tries to open a restricted page, task, file, or result.
2. The system checks the student’s institution, group, assignment, and permissions.
3. If the student is not allowed, the system blocks the action.
4. The system shows a clear permission message.

Example messages:

- “You do not have permission to access this page.”
- “This topic is not assigned to you.”
- “This assignment is not assigned to you.”
- “This blitz task is not active.”
- “This task is closed.”
- “You cannot access another student’s result.”
- “You cannot access data from another institution.”

This protects student privacy, institution data, and task integrity.

### Student Flow Boundaries

The Student role is limited to learning and assigned task completion.

Students cannot:

- Create official Topics/materials/tasks.
- Activate Blitz tasks.
- Configure institution settings or task attempt counts.
- Grant their own Blitz exception attempt.
- Bypass Homework deadline or three-attempt limit.
- Bypass the authoritative Blitz timer.
- Change device time to gain extra time.
- Edit a submitted or auto-finalized attempt.
- View other Students' answers, files, scores, or private progress.
- Check answers, assign manual scores, or change categories.
- Release results.
- Access another institution's data.

The backend must enforce these restrictions even when the interface hides the related actions.
### MVP Student Flow Summary

The MVP Student flow includes:

1. Login and view Student dashboard.
2. View assigned Topics and supported learning materials.
3. View Homework instructions and institution-local deadline.
4. Receive exactly 3 normal Homework attempts.
5. See current and remaining Homework attempts.
6. Submit each Homework attempt separately.
7. Upload supported submission files up to the effective 15 MB limit.
8. Have the highest valid completed Homework score selected as official after checking.
9. Access Blitz only after Teacher activation.
10. Follow synchronized or individual timer-start behavior.
11. Receive exactly 1 normal Blitz attempt.
12. Receive at most 1 additional Teacher-approved Blitz attempt for a valid reason.
13. See whole-Blitz remaining time.
14. Explicitly submit before timeout or have saved work auto-finalized at timeout.
15. Receive zero for unanswered Blitz questions at timeout.
16. Wait for Teacher review where required.
17. Receive approved partial credit for supported objective question types.
18. View task/review status.
19. View personal result only after Student release.
20. See released scores with one decimal place.
21. View understanding category and allowed feedback.
22. View personal progress.
23. Use desktop and mobile according to task needs.
24. Remain inside own institution/task scope.

## 6. Parent Flow

The **Parent** flow explains how parents use **TestLabUz** to monitor their child’s learning progress.

The Parent is a monitoring user in the system. Parents do not create topics, upload learning materials, complete homework assignments, answer blitz tasks, check student answers, manage users, or change educational data.

The main purpose of the Parent flow is to give parents a simple and clear way to understand how their child is studying, which tasks were completed, what results were received, and which topics may need more revision or teacher support.

A parent belongs to one educational institution and is connected to one or more students inside that institution. A parent should only see information about their own child or children.

In the MVP version, the Parent flow should focus on viewing child progress, topic status, homework completion, blitz results, final scores, understanding categories, and teacher feedback if available.

Parents should use the mobile version of the platform in the MVP. Their interface should be simple, fast, and focused on progress monitoring.

### Main Parent Flow

1. The Parent logs in to the mobile application.
2. The system checks role, institution, connected children, account status, and permissions.
3. The Parent dashboard opens.
4. The Parent selects a connected child if needed.
5. The Parent views allowed progress and task-completion information.
6. The Parent opens a Topic.
7. The system checks the institution's Parent result-visibility mode.
8. If the mode is **with Student**, the Parent sees the result only after Student release.
9. If the mode is **manual Teacher release**, the Parent sees the result only after Student release and a separate Teacher release.
10. If the mode is **hidden**, the Parent does not receive the Topic result.
11. The Parent may view released scores, understanding category, completion information, and allowed Teacher feedback.
12. The Parent identifies Topics where the child may need revision or Teacher support.
13. The Parent logs out.

A Parent must never receive a result before the Student result has been released.
### Parent Dashboard Flow

After login, the parent should see the Parent dashboard.

The dashboard should give a clear overview of the child’s learning progress. It should help the parent quickly understand whether the child is completing tasks and whether there are topics that need attention.

The dashboard may show:

- Connected child or children
- Recent assigned topics
- Homework completion status
- Blitz task completion status
- Recent homework scores
- Recent blitz scores
- Final results if available
- Understanding categories
- Topics that need revision
- Topics that need teacher support
- Teacher feedback if available
- General learning progress

The dashboard should not show teacher management tools, student task submission tools, admin settings, or data from other students.

### Connected Children Flow

A parent may be connected to one child or more than one child.

The connected children flow is:

1. The parent opens the Parent dashboard.
2. The system shows the child or children connected to the parent account.
3. If there is only one child, the system shows that child’s progress directly.
4. If there is more than one child, the parent selects which child to view.
5. The system opens progress information only for the selected child.

The system should support these relationships:

- One parent can be connected to one student.
- One parent can be connected to multiple students.
- One student can be connected to one or more parents.

The parent should never be able to view students who are not connected to their account.

### Child Topic Progress Flow

The parent should be able to view topics assigned to their child.

The child topic progress flow is:

1. The parent opens the child’s progress page.
2. The system shows topics assigned to the child.
3. The parent selects a topic.
4. The system opens the topic progress details.
5. The parent views the topic status, homework status, blitz status, final result, and understanding category if available.

Topic progress information may include:

- Topic title
- Subject
- Teacher
- Group or class
- Homework completion status
- Blitz completion status
- Final result status
- Understanding category
- Teacher feedback if available

The parent should use this flow to understand what the child is currently studying and whether the child is progressing normally.

### Homework Completion Flow

The parent should be able to see whether the child completed homework assignments.

The homework completion flow is:

1. The parent opens a child’s topic or progress page.
2. The system shows homework assignments connected to the topic.
3. The parent views the homework completion status.
4. If the homework is checked and released, the parent may view the homework score.
5. If teacher feedback is available, the parent may view it.

Homework status may include:

- Not started
- In progress
- Submitted
- Waiting for teacher review
- Checked
- Not completed
- Closed

The parent should not be able to complete homework for the child, upload files, edit answers, or change homework status.

### Blitz Result Flow

The Parent may view the child's Blitz progress/result only when visibility rules allow it.

1. The Parent opens a connected child's Topic.
2. The system may show non-sensitive completion/review status that institution policy allows.
3. The system checks whether the Student result has been released.
4. If Student release has not occurred, result values remain hidden from the Parent.
5. After Student release:
   - `with_student`: the Parent receives result access automatically.
   - `manual_teacher`: the Parent waits for a separate Teacher release.
   - `hidden`: the Parent does not receive the result.
6. When visible, the Parent may see the official Blitz score and final Topic result information.
7. The Parent cannot open the live Blitz as a Student or interact with Student answers.

The Blitz result is monitoring information for the Parent, not an editable assessment record.
### Final Result Viewing Flow

The Parent can view a child's final Topic result only according to the approved Parent visibility mode.

1. The Parent opens a connected child's Topic result.
2. The system verifies the Parent–Student relationship.
3. The system checks that the Student result has been released.
4. The system evaluates the institution's Parent visibility mode:
   - **With Student** — visible after Student release.
   - **Manual Teacher release** — visible only after a separate Teacher release.
   - **Hidden** — not visible.
5. If visible, the system shows official Homework score, official Blitz score, final score, understanding category, completion status, and allowed feedback.
6. Numeric scores are displayed with one decimal place.
7. If hidden, the system does not expose result values.

The Parent cannot edit scores, categories, feedback, submissions, release status, or other learning data.
### Understanding Category Flow

The parent should be able to understand the child’s learning level through clear categories.

The MVP understanding categories are:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The understanding category flow is:

1. The parent opens the child’s progress or result page.
2. The system shows the understanding category for each topic if available.
3. The parent reads which topics are completed well and which topics need attention.
4. The parent identifies whether the child needs revision or teacher support.

The category should help the parent understand the result more clearly than a numeric score alone.

For example:

- **Understood well** means the child has strong understanding of the topic.
- **Partially understood** means the child understands some parts but still has gaps.
- **Needs revision** means the child should review the topic again.
- **Needs teacher support** means the child may need direct help from the teacher.
- **Not completed** means the child did not complete the required homework, blitz task, or both.

### Teacher Feedback Viewing Flow

Teacher feedback is visible to the Parent only when both of these conditions are satisfied:

1. The feedback is intended to be Parent-visible.
2. The related result/progress item is visible under the institution's Parent result-visibility policy.

The Parent opens the child's Topic or result page, the system checks the relationship and visibility policy, and then shows allowed feedback.

The Parent can read feedback only. Messaging, replies, and editing are outside the MVP.
### Child Progress Overview Flow

The parent should be able to view a simple progress overview for the child.

The child progress overview flow is:

1. The parent opens the child’s progress section.
2. The system shows only learning data for the selected child.
3. The parent views assigned topics, completion statuses, scores, and understanding categories.
4. The parent identifies topics that are completed successfully.
5. The parent identifies topics that need revision or teacher support.

The progress overview may show:

- Total assigned topics
- Completed topics
- Topics waiting for teacher review
- Topics not completed
- Recent homework results
- Recent blitz results
- Final understanding categories
- Topics needing revision
- Topics needing teacher support

The progress overview should be simple and easy to understand on mobile.

### Multiple Children Switching Flow

If a parent has more than one child connected to their account, the parent should be able to switch between children.

The multiple children switching flow is:

1. The parent opens the Parent dashboard.
2. The system shows connected children.
3. The parent selects one child.
4. The system shows progress for that child only.
5. The parent switches to another child if needed.
6. The system updates the dashboard and progress information for the newly selected child.

The system should clearly show which child’s progress is currently being viewed.

This prevents confusion when a parent has multiple children in the same institution or in different groups inside the same institution.

### Parent Mobile Flow

Parents should use the mobile version of **TestLabUz** in the MVP.

The parent mobile flow may include:

1. The parent logs in from mobile.
2. The system opens the Parent dashboard.
3. The parent selects a connected child if needed.
4. The parent views child progress.
5. The parent opens assigned topics.
6. The parent checks homework completion.
7. The parent checks blitz results.
8. The parent views final results and understanding categories.
9. The parent reads teacher feedback if available.
10. The parent identifies topics that need revision or teacher support.

The parent mobile interface should be focused on quick progress monitoring. It should not include complex desktop management tools.

### Access Restriction Flow

If a parent tries to access information outside their allowed scope, the system should block access.

The access restriction flow is:

1. The parent tries to open a restricted page, topic, task, file, result, or student profile.
2. The system checks the parent’s institution, connected child relationship, role, and permissions.
3. If the parent is not allowed, the system blocks the action.
4. The system shows a clear permission message.

Example messages:

- “You do not have permission to access this page.”
- “This student is not connected to your account.”
- “You cannot access another child’s progress.”
- “You cannot change learning results.”
- “You cannot access data from another institution.”
- “This result is not available yet.”

This protects student privacy and prevents parents from accessing unrelated data.

### Parent Flow Boundaries

The Parent role is read-only and limited to connected children.

Parents cannot:

- Create or manage educational content.
- Complete Homework or Blitz for the child.
- Upload Student answers.
- Change Student submissions, scores, categories, or statuses.
- Grant additional Blitz attempts.
- Release results.
- View a result before Student release.
- Bypass the institution's Parent visibility mode.
- View unrelated Students or other Parents' data.
- Manage users, groups, or institution settings.
- Access another institution's data.

Parent progress visibility must never expand beyond the explicit Parent–Student relationship and the institution's release policy.
### MVP Parent Flow Summary

The MVP Parent flow includes:

1. Login from mobile.
2. View Parent dashboard.
3. View connected child or children.
4. Switch between connected children.
5. View allowed Topic and completion progress.
6. View Homework and Blitz completion/review status where permitted.
7. Respect Student result release as the prerequisite for Parent result visibility.
8. Support Parent visibility mode `with_student`.
9. Support Parent visibility mode `manual_teacher`.
10. Support Parent visibility mode `hidden`.
11. View released official Homework score.
12. View released official Blitz score.
13. View released final Topic score.
14. View released understanding category.
15. View allowed Teacher feedback.
16. Identify Topics needing revision or Teacher support.
17. Remain read-only.
18. Block access to unrelated children and institutions.

## 7. Topic Learning Flow

The **Topic Learning Flow** explains the full learning process around one topic in **TestLabUz**.

A topic is the center of the learning-check process. It connects the teacher’s lesson, uploaded learning materials, homework assignment, blitz task, student submissions, scores, final result, and understanding category.

The purpose of this flow is to show how one topic moves from preparation to student learning, task completion, blitz verification, result calculation, and progress review.

In the MVP version, this flow should stay simple and practical. The goal is not to create a complex course system at the beginning. The goal is to make sure teachers can create a topic, give students materials and homework, verify understanding through a blitz task, and see the student’s real learning level.

### Main Topic Learning Flow

The main Topic Learning Flow is:

1. The Teacher opens an assigned group and creates a Topic.
2. The Teacher adds Topic information and instructions.
3. The Teacher uploads one or more learning materials.
4. The Teacher creates one or more Homework assignments.
5. Before Student attempts begin, exactly one Homework is designated as the official result-bearing Homework.
6. The Topic becomes available when active.
7. Students study the materials.
8. Each Student receives exactly 3 normal attempts for the official Homework.
9. The system records all Homework attempts and completes required checking.
10. The highest valid completed Homework score becomes official.
11. The Teacher creates one or more Blitz tasks for the same Topic.
12. Before Student attempts begin, exactly one Blitz is designated as the official result-bearing Blitz.
13. The Teacher sets the whole-Blitz duration.
14. During class, the Teacher activates the Blitz.
15. The system applies synchronized or individual timer-start mode.
16. Each Student normally receives one Blitz attempt.
17. If a valid technical/approved issue occurs, the Teacher may grant one additional Student-specific Blitz attempt with a reason.
18. The Student submits before timeout or the system auto-finalizes saved work at timeout.
19. The system and Teacher complete required checking.
20. The official Blitz score becomes available.
21. The system compares official Homework and Blitz scores using unrounded values.
22. The system calculates the final Topic result using the approved threshold formula.
23. The system assigns an understanding category using the derived integer `category_score`.
24. The Teacher reviews progress.
25. The Student receives the result according to Student release mode.
26. The Parent receives the result according to Parent visibility mode.
27. The Teacher closes or archives the Topic when appropriate.

A Topic may contain multiple supplementary Homework and Blitz tasks, but only the designated official pair contributes to the final Topic result.
### Topic Creation Flow

The topic learning process starts when the teacher creates a topic.

The topic creation flow is:

1. The teacher opens the assigned group or topic section.
2. The teacher clicks “Create Topic”.
3. The system opens the topic creation form.
4. The teacher enters the topic title.
5. The teacher adds a topic description.
6. The teacher selects or enters the subject.
7. The teacher selects the group or class.
8. The teacher adds student instructions.
9. The teacher sets the topic status.
10. The teacher saves the topic.
11. The system validates the information.
12. If the information is valid, the system creates the topic.

Topic information may include:

- Topic title
- Topic description
- Subject
- Group or class
- Teacher
- Lesson date if needed
- Instructions for students
- Topic status

The topic should belong to the correct institution, teacher, and group. A teacher should only create topics for groups assigned to them.

### Topic Status Flow

Topic status controls whether students can access the topic and whether the learning process is still active.

In the MVP version, the system may support simple topic statuses:

- Draft
- Active
- Closed
- Archived

The topic status flow is:

1. The teacher creates a topic as draft.
2. While the topic is draft, students cannot access it.
3. The teacher adds learning materials and homework assignment.
4. When the topic is ready, the teacher changes the topic status to active.
5. Students assigned to the group can now access the topic.
6. After the homework and blitz process is finished, the teacher may close the topic.
7. A closed topic no longer accepts new homework or blitz submissions according to rules.
8. Later, the teacher may archive the topic for history.

A draft topic is useful when the teacher is still preparing materials, assignments, or blitz tasks.

An active topic is visible to assigned students and can be used for learning.

A closed topic means the main learning-check process is finished.

An archived topic is kept for history and reports but is no longer actively used.

### Learning Material Connection Flow

After creating a Topic, the Teacher uploads learning materials.

1. The Teacher opens the Topic.
2. The Teacher chooses **Upload Material**.
3. The system shows supported formats and the effective file-size limit.
4. The Teacher selects PDF, DOCX, PPT, or PPTX.
5. The client may pre-check the file.
6. The backend validates file type, effective size limit, Topic ownership, institution, and permission.
7. The platform hard maximum is **25 MB per file**; a lower institution limit may apply.
8. A valid file is uploaded and connected to the Topic.
9. Assigned Students can open/download it while access rules allow.
10. Invalid, oversized, or failed uploads are rejected.

A Topic may contain multiple learning materials.
### Homework Assignment Connection Flow

A Topic may contain multiple Homework assignments.

1. The Teacher opens the Topic.
2. The Teacher creates one or more Homework assignments.
3. Each Homework inherits the correct Topic/institution/group scope.
4. Before any Student starts the result-bearing Homework, the Teacher designates exactly one Homework as **official for Topic result calculation**.
5. The system validates that the designated Homework belongs to the Topic and assigned scope.
6. Other Homework tasks remain supplementary and do not affect the final Topic formula.
7. After Student attempts begin on the designated Homework, the designation cannot be replaced in a way that changes existing result meaning.

The official Homework provides the `H` score used with the official Blitz for this Topic.
### Student Topic Study Flow

After the Topic becomes active, the Student can study it.

1. The Student opens an assigned Topic.
2. The system shows Topic information, instructions, materials, Homework status, Blitz availability, and result status.
3. The Student opens or downloads learning materials.
4. The Student studies independently.
5. The Student sees the official Homework instructions, deadline if any, and the fixed **3 normal attempts**.
6. The Student understands that a Blitz verification task will be used later.

The Student never sees Topics or private task data outside their authorized scope.
### Homework Completion Inside Topic Flow

After studying the materials, the Student completes the official Homework.

1. The Student opens the Topic and official Homework.
2. The system shows instructions, deadline, current attempt, and remaining attempts.
3. The Student starts one of the 3 normal attempts.
4. The Student answers and submits.
5. The system stores the attempt separately.
6. Automatic scoring is applied where possible.
7. Manual answers wait for Teacher review.
8. If attempts remain and the task/deadline still allow it, the Student may start another attempt.
9. After required checking, the system compares valid completed attempt scores.
10. The highest valid completed score becomes the official Homework score.
11. No fourth normal Homework attempt is allowed.

The official Homework score is only the first input to the Topic result and is not the final understanding result by itself.
### Blitz Task Connection Flow

The Topic may contain multiple Blitz tasks.

1. The Teacher creates one or more Blitz tasks for the Topic.
2. The Teacher sets each Blitz's whole-task duration.
3. Before Students start the result-bearing Blitz, the Teacher designates exactly one Blitz as official for the Topic result.
4. The system validates that the official Blitz and official Homework belong to the same Topic.
5. Other Blitz tasks remain supplementary.
6. The Teacher activates the official Blitz during class.
7. Once Student attempts begin, the official designation cannot be replaced in a way that changes existing result meaning.

The official Blitz provides the `B` score used in the Topic result formula.
### In-Class Blitz Flow Inside Topic

The official Blitz is used during class, usually in the first 5–10 minutes.

1. The Teacher opens the prepared official Blitz.
2. The system shows recipients, duration, fixed one-normal-attempt rule, and institution timer-start mode.
3. The Teacher activates it.
4. In synchronized mode, the server starts the countdown for all assigned Students at activation.
5. In individual mode, the task becomes available and each Student receives the full duration from that Student's server-recorded start time.
6. The Student answers while time remains.
7. The Student may submit before timeout.
8. If time reaches zero, the backend auto-finalizes saved answers and rejects further writes.
9. Unanswered questions receive zero.
10. Manual-review answers remain waiting for Teacher judgment.
11. If a valid technical/approved issue prevented proper completion, the Teacher may grant that Student one additional Blitz attempt and record a reason.
12. The original invalid/interrupted attempt remains in history.
13. The system completes automatic/manual scoring and identifies the official Blitz score.

The server clock is authoritative.
### Topic Result Calculation Flow

After the official Homework and Blitz scores are ready, the system calculates the Topic result.

Let:

- `H` = official Homework score
- `B` = official Blitz score
- `D = |H - B|`
- `T` = institution acceptable difference threshold

Flow:

1. Confirm the designated official Homework and Blitz belong to the same Topic/Student context.
2. Confirm all required manual review is complete.
3. Use unrounded `H` and `B`.
4. Calculate `D`.
5. Compare `D` to `T`.
6. If `D <= T`, calculate `(H + B) / 2`.
7. If `D > T`, use `B`.
8. Assign the understanding category using the derived integer `category_score`.
9. Store the calculation method, threshold snapshot, category-rule snapshot, and relevant official attempt references.
10. Display scores to users with **one decimal place**.
11. Keep calculation state separate from Student/Parent visibility.
12. Apply the institution's release modes.

Changing display rounding must never change the formula or category.
### Understanding Category Flow Inside Topic

After the final result is calculated, the system assigns an understanding category.

The MVP understanding categories are:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The understanding category flow is:

1. The system calculates the final topic score.
2. The system checks the institution’s category score ranges.
3. The system assigns the correct understanding category.
4. The category appears in the teacher’s topic result page.
5. The student may see the category if results are released.
6. The parent may see the category if parent visibility is allowed.
7. The teacher uses the category to decide what support the student needs.

These categories help users understand the result more clearly than a numeric score alone.

### Topic Progress Review Flow

The teacher should be able to review topic progress for the whole group.

The topic progress review flow is:

1. The teacher opens the topic result or topic progress page.
2. The system shows the list of assigned students.
3. The system shows homework completion status.
4. The system shows blitz completion status.
5. The system shows homework scores.
6. The system shows blitz scores.
7. The system shows final results.
8. The system shows understanding categories.
9. The teacher filters students by completion status or category.
10. The teacher identifies students who need revision or teacher support.

The topic progress page may show:

- Student name
- Homework status
- Blitz status
- Homework score
- Blitz score
- Score difference
- Final result
- Understanding category
- Manual review status
- Attempt information
- Teacher feedback if available

This helps the teacher understand how the whole group performed on one topic.

### Student Topic Result Flow

The Student views their own Topic result only after Student release.

1. The Student opens the Topic.
2. The system checks result calculation status.
3. The system separately checks Student visibility.
4. If Student mode is `automatic`, a fully calculated result is released automatically.
5. If Student mode is `manual_teacher`, the result remains hidden until Teacher release.
6. When visible, the Student sees official Homework score, official Blitz score, final score, category, completion status, and allowed feedback.
7. Scores are displayed with one decimal place.

A calculated but unreleased result is not incomplete.
### Parent Topic Progress Flow

The Parent views Topic result information only for a connected child and only after Student release.

1. The Parent opens the mobile app and selects a connected child.
2. The Parent opens Topic progress.
3. The system verifies the Parent–Student relationship.
4. The system checks Student release.
5. The system applies Parent visibility mode:
   - `with_student`: visible after Student release.
   - `manual_teacher`: visible after Student release plus separate Teacher release.
   - `hidden`: result values remain hidden.
6. When visible, the Parent may see official Homework/Blitz scores, final score, category, completion status, and allowed feedback.
7. The Parent remains read-only.
### Incomplete Topic Flow

The system distinguishes waiting, not completed, calculated, and visibility states.

A Topic result may be waiting when:

- Official Homework score is not yet available.
- Official Blitz score is not yet available.
- Required manual review is still pending.

A result becomes **Not completed** only when required work can no longer validly be completed after the applicable Homework attempts/deadline or Blitz availability/attempt rules end.

Important distinctions:

- Waiting for Teacher review is **not** Not completed.
- A calculated result hidden from Student/Parent is **not** incomplete.
- An approved extra Blitz attempt may keep the Blitz requirement open until that opportunity is completed or no longer valid.

Flow:

1. Check official Homework readiness.
2. Check official Blitz readiness.
3. Check manual review.
4. Determine waiting/calculated/not-completed state.
5. Separately determine Student visibility.
6. Separately determine Parent visibility.
7. Recalculate an open result when an allowed underlying score correction changes an input.
### Topic Access and Data Separation Flow

Topic access must follow role, institution, group, and user relationship rules.

The access flow is:

1. A user tries to open a topic.
2. The system checks the user’s institution.
3. The system checks the user’s role.
4. The system checks whether the user is connected to the topic’s group, student, or child relationship.
5. If access is allowed, the system opens the topic.
6. If access is not allowed, the system blocks access and shows a permission message.

Access rules should work like this:

- Super Admin may manage platform-level institution access but should not normally interfere with daily topic learning.
- Institution Admin may view topic activity inside their own institution for management and support.
- Teacher may manage topics only for assigned groups.
- Student may view only assigned topics.
- Parent may view only their own child’s topic progress.
- Users from another institution must not access the topic.

Example permission messages:

- “You do not have permission to access this topic.”
- “This topic is not assigned to you.”
- “This group is not assigned to you.”
- “You cannot access another student’s result.”
- “You cannot access data from another institution.”

This protects institution data, student privacy, and teacher content.

### Topic Device Flow

The topic learning flow should work according to the approved device access model.

The device flow is:

1. Teachers use desktop for creating topics, uploading materials, building homework, creating blitz tasks, checking answers, and reviewing detailed topic results.
2. Teachers may use mobile for quick topic status, blitz activation, and class progress monitoring.
3. Students use desktop for reading larger materials, writing longer answers, uploading files, and reviewing progress.
4. Students use mobile for quick study, simple tasks, and blitz participation.
5. Parents use mobile to view topic progress and child results.
6. Institution Admins use desktop to view basic topic activity and reports inside their institution.
7. Super Admins use desktop for platform-level monitoring, not daily topic work.

Each device version should show only the topic actions that match the user’s role and responsibility.

### Topic Learning Flow Boundaries

The topic learning flow should stay focused and controlled in the MVP.

The topic flow should not include:

- AI-generated topic content
- AI-generated homework
- AI-generated blitz tasks
- Audio materials
- Video materials
- Communication tools
- Teacher-parent messaging
- Student comments
- Advanced analytics
- Monetization rules
- External integrations
- Complex topic templates
- Material version history
- Advanced course builder logic

These features can be added later after the core topic learning process works clearly.

In the MVP, the topic should mainly connect:

- Teacher explanation
- Uploaded learning materials
- Homework assignment
- Blitz task
- Homework result
- Blitz result
- Final result
- Understanding category
- Progress visibility

### MVP Topic Learning Flow Summary

The MVP Topic Learning Flow includes:

1. Create Topic in assigned scope.
2. Upload supported learning materials up to the effective 25 MB limit.
3. Create multiple Homework tasks if needed.
4. Designate exactly one official result-bearing Homework before attempts begin.
5. Give each Student exactly 3 normal Homework attempts.
6. Select the highest valid completed Homework score as official.
7. Create multiple Blitz tasks if needed.
8. Designate exactly one official result-bearing Blitz before attempts begin.
9. Set whole-Blitz duration.
10. Activate Blitz in class.
11. Apply synchronized or individual timer-start mode.
12. Give one normal Blitz attempt.
13. Permit one Student-specific Teacher-approved extra Blitz attempt for a valid reason.
14. Auto-finalize saved Blitz work at timeout and give zero for unanswered questions.
15. Complete automatic/manual checking with approved partial-credit rules.
16. Compare official Homework and Blitz scores using unrounded values.
17. Apply the threshold formula using unrounded values, then derive `category_score` for the category.
18. Display scores with one decimal place.
19. Keep calculation and visibility separate.
20. Apply Student and Parent release modes.
21. Review progress and support needs.
22. Preserve historical attempts/results when Topic is closed or archived.
23. Protect all access by institution, role, group, Student, and Parent relationship.

## 8. Homework Assignment Flow

The **Homework Assignment Flow** explains how homework assignments are created, assigned, completed, submitted, checked, and scored in **TestLabUz**.

Homework assignments are an important part of the topic-based learning-check process. They help the teacher check how well students understood the topic after studying the uploaded learning materials independently.

In **TestLabUz**, homework is not used alone as the final proof of understanding. The homework result is later compared with the blitz task result for the same topic. This helps the teacher understand whether the student’s homework result reflects real understanding or may have been completed with outside help.

In the MVP version, homework assignments should stay practical and focused. The goal is to let teachers create structured tasks, let students complete them, record homework results, and prepare the system for comparison with the blitz task result.

### Main Homework Assignment Flow

The Homework Assignment Flow explains how Homework is created, assigned, attempted, submitted, checked, scored, and connected to the Topic result.

The main Homework flow is:

1. The Teacher creates Homework for an assigned Topic.
2. The Teacher adds instructions, questions, points, and optional deadline.
3. The system applies the fixed rule of **3 normal attempts per Student**.
4. If a Topic contains multiple Homework tasks, exactly one is designated as the official result-bearing Homework before Student attempts begin.
5. The Homework becomes active.
6. The Student opens the Homework and sees 3 total attempts, current attempt, remaining attempts, and deadline.
7. The Student completes and submits an attempt.
8. The system stores each attempt separately.
9. The system scores objective parts automatically using the approved scoring rules.
10. Manual answers wait for Teacher review.
11. The Student may use the remaining normal attempts while the task/deadline still allows it.
12. After required checking, the system chooses the **highest valid completed attempt score** as the official Homework score.
13. The Teacher views Homework progress and official score.
14. Student/Parent result visibility follows the approved release rules.
15. The official Homework score later participates in the Topic Homework–Blitz comparison.

Homework remains evidence from home study; it is not the final Topic result by itself.
### Homework Creation Flow

The Teacher creates Homework from an assigned Topic.

1. Open the Topic.
2. Click **Create Homework Assignment**.
3. Enter title, description, Student instructions, recipients, questions, answer data, and points.
4. The system shows the fixed **3-attempt** rule; the Teacher does not edit this value.
5. The Teacher may add an institution-local deadline.
6. The Teacher selects lifecycle status.
7. If this Homework should drive the Topic result, the Teacher designates it as the official result-bearing Homework before Student attempts begin.
8. The system validates Topic, institution, group/Student scope, questions, scoring data, and designation.
9. The Homework is saved.
10. Once Students begin attempts on the official Homework, the designation cannot be replaced in a way that changes existing result meaning.

Homework information may include:

- Title and description
- Topic
- Group or selected Students
- Instructions
- Questions and types
- Answer options/correct answers where applicable
- Points
- Fixed 3-attempt rule
- Deadline if applicable
- Lifecycle status
- Result-bearing designation
### Homework Topic Connection Flow

Every Homework belongs to one Topic.

A Topic may contain multiple Homework assignments, but the MVP Topic result uses exactly one designated official Homework.

1. The Teacher creates Homework from the Topic.
2. The system connects it to that Topic and authorized group/Students.
3. Before attempts begin, the Teacher designates one Homework as official for result calculation.
4. Supplementary Homework tasks do not affect the final Topic formula.
5. The official Homework score is later compared only with the designated official Blitz score from the same Topic and Student.

The designation is protected after Student attempts begin.
### Homework Assignment Status Flow

Homework lifecycle and Student submission/review states are separate.

Homework lifecycle statuses:

- Draft
- Active
- Closed
- Archived

Student-level submission/review states may include:

- Not started
- In progress
- Submitted
- Waiting for Teacher review
- Checked
- Not completed

Flow:

1. Homework starts as Draft.
2. Draft Homework is not available for Student completion.
3. The Teacher activates valid Homework.
4. Assigned Students may start attempts while deadline and attempt rules permit.
5. Closing the Homework blocks new attempts/submissions.
6. Existing submitted attempts may still be checked.
7. Archived Homework remains historical and accepts no new activity.

`Waiting for Teacher review` and `Checked` must not be used as Homework lifecycle statuses.
### Assignment Type Flow

The teacher should be able to create homework using the supported MVP assignment types.

The MVP assignment types are:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

The assignment type flow is:

1. The teacher selects an assignment type.
2. The system shows the correct question builder for that type.
3. The teacher adds the question text or task instruction.
4. The teacher adds answer options if the type requires options.
5. The teacher defines correct answers if automatic checking is possible.
6. The teacher defines points or score rules.
7. The teacher saves the question.
8. The teacher adds more questions if needed.
9. The teacher reviews the full assignment before activating it.

Different assignment types need different input fields.

For example:

- Single-choice tests need answer options and one correct answer.
- Multiple-choice tests need answer options and several correct answers.
- True / false questions need a statement and the correct true/false value.
- Short written answers may need accepted correct answers.
- Open written answers need instructions and manual checking.
- File-based assignments need upload instructions and file rules.
- Matching tasks need pairs of related items.
- Ordering tasks need items and the correct order.
- Fill-in-the-blank tasks need a text with missing parts and correct values.

This allows teachers to check student understanding in different ways.

### Homework Attempt Flow

Homework attempt count is fixed in the MVP.

1. The Student opens active Homework.
2. The system shows **3 total normal attempts**.
3. The system shows current attempt number and remaining attempts.
4. The Student starts attempt 1, 2, or 3 when allowed.
5. Each submitted attempt is stored separately and cannot overwrite an earlier attempt.
6. A submitted attempt is locked against Student edits.
7. If another normal attempt remains and deadline/status rules allow it, the Student may start it.
8. After attempt 3, the system blocks a fourth normal Homework attempt.
9. After required automatic/manual checking is complete, the system compares valid completed attempt scores.
10. The highest valid completed score becomes the official Homework score.

Example:

```text
Attempt 1: 60
Attempt 2: 82
Attempt 3: 75
Official Homework score: 82
```

The Institution Admin and Teacher do not change this attempt count in the MVP.
### Homework Deadline Flow

The Teacher may add a Homework deadline.

1. The Teacher enters the deadline in the institution's local timezone.
2. The UI identifies the institution timezone.
3. The backend interprets/converts the deadline to an authoritative UTC instant.
4. Students see the deadline in institution local time.
5. The backend compares server time with the stored deadline.
6. At the authoritative deadline, the backend blocks new Attempts and further Student answer changes.
7. Every existing `in_progress` Homework Attempt is automatically finalized using answers already saved on the server.
8. Answered components are evaluated normally; unanswered components receive zero; answered manual-review components remain waiting for Teacher review.
9. The backend records `homework_deadline_auto_submit`; `submitted_at` remains null because the Student did not explicitly submit.
10. Students who never started receive no fabricated Attempt, and unused remaining Homework attempts are no longer available.
11. Device clock/timezone changes cannot extend the deadline.
12. Changing the institution timezone later does not alter the historical absolute deadline instant.

Advanced late penalties and complex approval workflows remain outside the MVP.
### Student Homework Access Flow

Students should only access homework assignments assigned to them.

The student homework access flow is:

1. The student logs in to the platform.
2. The student opens the Student dashboard or assigned topic.
3. The system shows homework assignments assigned to the student.
4. The student opens the homework assignment.
5. The system checks whether the homework is active.
6. The system checks whether the student has permission.
7. If access is allowed, the system shows the homework instructions and questions.
8. If access is not allowed, the system blocks access and shows a clear message.

Students should not access:

- Homework from another institution
- Homework from an unrelated group
- Homework assigned to another student
- Draft homework
- Archived homework
- Closed homework that no longer allows access
- Homework after attempts are finished if rules block it

### Student Homework Answering Flow

The Student completes active Homework.

1. Open assigned Homework.
2. Review instructions, deadline, current attempt, and remaining attempts.
3. Start an available attempt.
4. Answer each question.
5. Upload a file when required, within the effective 15 MB limit.
6. Review answers if allowed.
7. Submit the attempt.
8. The backend validates Student assignment, institution scope, task lifecycle, deadline, attempt number, answers, and files.
9. A valid attempt is stored and locked.
10. Automatic scoring starts where possible.
11. Manual answers wait for Teacher review.
12. If normal attempts remain, the Student may start another attempt while task/deadline rules permit.

The interface should never imply that attempts are configurable; it should show the fixed 3-attempt rule.
### File-Based Homework Flow

For file-based Homework, the Student can upload PDF, DOCX, PPT, or PPTX.

1. Open the file-based Homework question.
2. The system shows allowed formats and effective size limit.
3. The Student selects a file.
4. The client may pre-check size/type.
5. The backend authoritatively validates file type, size, ownership, attempt, task, and institution.
6. Platform hard maximum: **15 MB per Student submission file**.
7. A lower institution limit may apply.
8. If valid, the file is attached to that specific attempt.
9. The Student submits.
10. The Teacher later reviews and assigns points.
11. Failed, unsupported, or oversized uploads do not become valid answers.

Clear validation errors should explain the effective limit.
### Homework Submission Recording Flow

After the student submits homework, the system should record the submission.

The submission recording flow is:

1. The student submits the homework.
2. The system validates the submission.
3. The system records the student.
4. The system records the assignment.
5. The system records the topic.
6. The system records the group.
7. The system records the attempt number.
8. The system records submitted answers.
9. The system records uploaded files if available.
10. The system records submission time.
11. The system records checking status.
12. The system records score if automatic checking is possible.
13. The system records teacher feedback later if manual checking is needed.

Submission information may include:

- Student
- Institution
- Group
- Topic
- Homework assignment
- Attempt number
- Submitted answers
- Submitted file if applicable
- Submission time
- Score if available
- Checking status
- Teacher feedback if available

This data is important for scoring, reports, progress tracking, and later comparison with the blitz result.

### Automatic Checking Flow

Objective Homework answers are scored according to approved rules.

1. The Student submits an attempt.
2. The system identifies each question type.
3. The system applies:
   - Single-choice: all-or-nothing.
   - True / false: all-or-nothing.
   - Multiple-choice: partial credit based on correctly selected options divided by total correct options, with Student selections capped at the number of correct options.
   - Matching: partial credit per correctly matched pair.
   - Ordering: partial credit per correctly positioned item.
   - Fill-in-the-blank: partial credit per correctly completed blank.
   - Short written: automatic only when accepted-answer rules allow.
4. The system calculates automatic points.
5. If no manual review is needed, the attempt score becomes complete.
6. If manual review is needed, the attempt remains pending until Teacher scoring is complete.
7. Attempt scores remain separate across all three Homework attempts.
### Manual Checking Flow

Some Homework answers require Teacher review.

1. The system marks the relevant submission as waiting for Teacher review.
2. The Teacher opens the immutable Student answer/file.
3. The Teacher reviews it.
4. The Teacher assigns points within the allowed maximum.
5. The Teacher may add feedback.
6. The Teacher saves the review.
7. The system completes the attempt score when all required questions are scored.
8. If an allowed correction is made before Topic result closure, dependent official-score selection and Topic result are recalculated.
9. The Teacher cannot rewrite the Student answer or directly override the final Topic formula.

Open written and file-based answers require manual review; short written answers may also require it.
### Homework Score Flow

The official Homework score is selected across the Student's valid completed Homework attempts.

1. Complete automatic/manual checking for each relevant attempt.
2. Normalize each completed attempt score to the common 0–100 scale.
3. Preserve internal precision; do not round before official selection.
4. Identify the highest valid completed score from the Student's 3 normal attempts.
5. Record that attempt as the official Homework attempt.
6. Record its score as the official Homework score.
7. The Teacher can view the official score and attempt history.
8. User-facing score display uses one decimal place.
9. The official Homework score becomes the `H` input to Topic result calculation.

A lower-scoring later attempt does not replace a higher valid earlier attempt.
### Homework Progress Monitoring Flow

The Teacher monitors Homework progress for assigned Students.

The progress view may show:

- Student
- Not started / in progress / submitted / waiting review / checked / not completed
- Current Homework attempt number
- Remaining attempts out of 3
- Scores for completed attempts
- Which attempt is official when determined
- Official Homework score
- Submission times
- Manual review status
- Feedback where available

The Teacher uses this information to prepare for the Blitz and identify Students needing help. The Teacher does not change the 3-attempt limit.
### Student Homework Result Flow

The Student sees Homework result information only according to Student result-release rules.

1. The Student opens the Homework/Topic.
2. The system may show attempt/completion status while work is ongoing.
3. The system determines the official Homework score after required checking.
4. The system checks Student result visibility.
5. When permitted, the Student sees the official Homework score, official-attempt indication, completion status, and allowed feedback.
6. The score is displayed with one decimal place.

A calculated official Homework score can exist internally before the full Topic result is released.
### Parent Homework Progress Flow

Parent Homework progress is read-only and subject to Parent visibility policy.

1. The Parent opens a connected child's Topic.
2. The system may show allowed Homework completion/review status.
3. Score visibility requires Student release first.
4. Parent mode is evaluated:
   - `with_student`: visible after Student release.
   - `manual_teacher`: visible after Student release plus Teacher release.
   - `hidden`: score remains hidden.
5. When visible, the Parent may see the official Homework score and allowed feedback.
6. The Parent cannot submit, upload, edit, score, or change status.
### Institution Admin Homework Overview Flow

Institution Admins may view basic homework activity inside their own institution.

The Institution Admin homework overview flow is:

1. The Institution Admin opens institution reports or group progress.
2. The system shows homework activity inside the institution.
3. The admin reviews completion overview by group, topic, or teacher.
4. The admin identifies groups or students that may need attention.
5. The admin uses the information for management and support.

Institution Admins should not normally change student answers, manually manipulate scores, or replace the teacher’s checking role.

### Homework Access and Data Separation Flow

Homework access must follow institution, role, group, and user relationship rules.

The access flow is:

1. A user tries to open a homework assignment.
2. The system checks the user’s institution.
3. The system checks the user’s role.
4. The system checks the user’s connection to the group, student, or child.
5. The system checks homework status and permission rules.
6. If access is allowed, the system opens the homework or progress page.
7. If access is not allowed, the system blocks access and shows a clear message.

Access rules should work like this:

- Teachers can create and manage homework only for assigned groups.
- Students can complete only homework assigned to them.
- Parents can view only their own child’s homework progress if allowed.
- Institution Admins can view homework overview only inside their own institution.
- Super Admins manage platform-level access but should not normally interfere with homework submissions.
- Users from another institution must not access homework, submissions, scores, or files.

Example permission messages:

- “You do not have permission to access this homework.”
- “This homework is not assigned to you.”
- “This assignment is closed.”
- “No further attempt is available for this task.”
- “You cannot access another student’s submission.”
- “You cannot access data from another institution.”

This protects student submissions, homework scores, uploaded files, and institution data.

### Homework Device Flow

Homework follows the approved device model.

1. Teachers use desktop for Homework authoring and detailed checking.
2. Teachers may use mobile for status/progress review.
3. Students use desktop for larger written/file work.
4. Students may use mobile for simple Homework types.
5. Parents use mobile for permitted progress/result viewing.
6. Institution Admins use desktop for overview/reporting.
7. Super Admins remain platform-focused.

Attempt, deadline, scoring, visibility, and access rules are identical across devices.
### Homework Flow Boundaries

The MVP Homework flow supports:

- Teacher-created Homework
- Topic connection
- Exactly one designated result-bearing Homework per Topic result
- Fixed 3 normal attempts
- Highest valid completed attempt as official score
- Optional institution-local deadline with UTC authoritative instant
- Nine supported question types
- Approved partial credit
- Automatic and manual checking
- 15 MB platform hard maximum for Student submission files
- Separate lifecycle/submission/review states
- Student/Parent visibility policies
- Historical attempt preservation
- Access protection

It does not include configurable attempt counts, advanced late-penalty workflows, AI grading, question banks, plagiarism detection, peer review, or complex grading workflows.
### MVP Homework Assignment Flow Summary

The MVP Homework Assignment Flow includes:

1. Teacher creates Homework for a Topic.
2. Homework is assigned to authorized Students.
3. Exactly one Homework is designated as official for the Topic result before attempts begin.
4. Student receives exactly 3 normal attempts.
5. Each attempt is recorded separately.
6. Student sees current and remaining attempts.
7. Teacher may add an institution-local deadline.
8. Backend enforces the authoritative UTC deadline instant.
9. Student answers supported question types.
10. Student file submissions respect the effective 15 MB limit.
11. System applies approved automatic/partial-credit rules.
12. Teacher completes required manual review.
13. System selects the highest valid completed Homework attempt as official.
14. Official score remains full precision internally and displays with one decimal place.
15. Teacher views Homework progress.
16. Student/Parent score visibility follows release policy.
17. Official Homework score becomes the `H` input to Topic result calculation.
18. Access and historical attempts are protected.

## 9. Blitz Task Flow

The **Blitz Task Flow** explains how Blitz tasks are created, designated, activated, timed, attempted, checked, scored, and used with the official Homework score in **TestLabUz**.

A Blitz is a short in-class verification task. Its purpose is to check real Topic understanding after Homework completed outside class.

A Topic may contain multiple Blitz tasks, but exactly **one Blitz** is designated as the official result-bearing Blitz before Student attempts begin. Each Student normally has exactly **1 Blitz attempt**. A Teacher may grant exactly **1 additional Student-specific Blitz attempt** for a valid technical or other approved reason, with a required reason record.

The Teacher sets one whole-Blitz duration. The Institution Admin chooses whether timing starts synchronously at Teacher activation or individually when each Student starts. The server clock is authoritative.

At timeout, the backend automatically finalizes saved answers. Unanswered questions receive zero, while answered questions requiring Teacher judgment remain waiting for manual review.

### Main Blitz Task Flow

1. The Teacher creates a manual Blitz for an assigned Topic.
2. The Teacher adds instructions, questions, points, and whole-Blitz duration.
3. If the Topic has multiple Blitz tasks, the Teacher designates exactly one as official for Topic result calculation before Student attempts begin.
4. The Teacher saves the Blitz as Draft or Scheduled.
5. During class, the Teacher opens the prepared Blitz.
6. The system shows the institution timer-start mode and fixed one-normal-attempt rule.
7. The Teacher activates the Blitz.
8. Assigned Students gain access.
9. In synchronized mode, the server starts the countdown for all assigned Students at activation.
10. In individual mode, each Student receives the full duration from their own server-recorded start.
11. Each Student normally uses one Blitz attempt.
12. The Student explicitly submits before timeout or the backend auto-finalizes saved work at timeout.
13. Unanswered questions receive zero.
14. The system applies automatic/partial-credit scoring where possible.
15. The Teacher checks manual answers.
16. If a valid technical/approved issue affected one Student, the Teacher may grant exactly one additional Blitz attempt with a reason.
17. The original invalid/interrupted attempt remains in history and is excluded from official scoring under the approved exception.
18. The system identifies the official Blitz score.
19. The system compares the official Blitz score with the official Homework score for the same Topic/Student.
20. The Topic result is calculated and categorized.
21. Teacher, Student, and Parent visibility follow their approved roles and release settings.
### Blitz Task Connection Flow

Each Blitz belongs to the correct institution, Teacher, Topic, group/Student assignment, questions, attempts, and results.

A Topic may contain multiple Blitz tasks, but only one is designated as the official result-bearing Blitz.

1. The Teacher creates a Blitz from a Topic.
2. The system connects it to the same authorized learning context.
3. Before Student attempts begin, the Teacher designates one Blitz as official.
4. The system verifies that the designated official Homework and Blitz belong to the same Topic.
5. Supplementary Blitz tasks do not affect the Topic result.
6. After Student attempts begin, the official designation cannot be replaced in a way that changes existing result meaning.
7. The official Blitz score is later compared only with the official Homework score for that Student/Topic.
### Blitz Task Creation Flow

The Teacher creates a Blitz manually.

1. Open an assigned Topic.
2. Click **Create Blitz Task**.
3. Enter title and Student instructions.
4. Add short questions.
5. Add answer options/correct-answer data where applicable.
6. Define points.
7. Set one **whole-Blitz duration**.
8. The system displays the fixed **1 normal attempt** rule.
9. The Teacher does not configure arbitrary attempt counts.
10. Save as Draft or Scheduled.
11. If this Blitz will drive Topic results, designate it as official before attempts begin.
12. The system validates content, scope, duration, and designation.

Blitz information may include:

- Title
- Topic
- Group or selected Students
- Instructions
- Questions
- Answer options/correct answers
- Points
- Whole-Blitz duration
- Fixed normal attempt rule
- Lifecycle status
- Official result-bearing designation
### Blitz Task Status Flow

Blitz lifecycle status is separate from Student attempt/review status.

Blitz lifecycle:

- Draft
- Scheduled
- Active
- Closed
- Archived

Student attempt/review states may include:

- Not started
- In progress
- Submitted
- Auto-finalized at timeout
- Waiting for Teacher review
- Checked
- Invalid due to approved exception
- Not completed

Flow:

1. Teacher prepares Draft.
2. Draft/Scheduled Blitz cannot be answered before activation.
3. Teacher activates it during class.
4. Active Blitz may be answered according to assignment, timer, and attempt rules.
5. Closing blocks new activity.
6. Existing submissions may still be reviewed.
7. Archived Blitz remains historical.

`Waiting for Teacher review` and `Checked` are Student-level states, not Blitz lifecycle values.
### Blitz Question Type Flow

Blitz tasks may use the same supported assignment types as homework, but they should usually stay shorter and faster.

The MVP assignment types are:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

The blitz question type flow is:

1. The teacher selects a question type.
2. The system shows the correct question builder.
3. The teacher adds the question text or task instruction.
4. The teacher adds answer options if needed.
5. The teacher defines correct answers if automatic checking is possible.
6. The teacher defines points or score rules.
7. The teacher saves the question.
8. The teacher adds more short questions if needed.
9. The teacher reviews the full blitz task before activation.

Because blitz tasks are used during the first 5–10 minutes of class, teachers should usually use faster question types, such as:

- Single-choice tests
- Multiple-choice tests
- True / false questions
- Short written answers
- Matching tasks
- Ordering tasks
- Fill-in-the-blank tasks

Open written answers and file-based assignments may be supported, but they are less suitable for short in-class blitz tasks because they may require more time and manual checking.

### Blitz Time Limit Flow

Blitz uses one whole-task duration.

1. The Teacher sets the duration, for example 5, 7, or 10 minutes.
2. The Institution Admin has already selected one timer-start mode for the institution.
3. The server stores/uses authoritative timestamps.

**Synchronized mode**

1. Teacher activates Blitz.
2. Server records `activated_at`.
3. Effective end is `activated_at + duration`.
4. All assigned Students share that end instant.
5. Late openers receive less remaining time.

**Individual mode**

1. Teacher activates Blitz so it becomes available.
2. Student presses Start.
3. Server records that Student attempt's `started_at`.
4. Effective end is `started_at + duration`.
5. Each Student receives the full configured duration.

For both modes:

- The Student always sees remaining whole-Blitz time.
- Device clock/timezone changes cannot extend time.
- At timeout, the backend stops accepting changes and auto-finalizes saved answers.
- Unanswered questions receive zero.
- Answers saved before the deadline are evaluated normally.
- Manual-review answers remain pending for Teacher judgment.
- Writes after the deadline are rejected.
### Blitz Attempt Flow

Blitz attempts are fixed.

#### Normal flow

1. Each assigned Student receives exactly **1 normal Blitz attempt**.
2. The Student starts/uses that attempt when timing/access rules allow.
3. The attempt is preserved after submit or timeout.
4. No automatic second normal attempt exists.

#### Approved exception

1. A Student experiences a valid technical or other approved problem.
2. The Student/Teacher identifies the issue.
3. The Teacher reviews the case.
4. If justified, the Teacher grants exactly **1 additional Blitz attempt** to that Student.
5. The Teacher must provide a reason.
6. The original affected attempt remains in history and is marked invalid/excluded from official scoring under the approved exception.
7. The additional valid attempt becomes the score-bearing Blitz attempt after checking.
8. The exception is Student-specific and does not affect classmates.
9. No third Blitz attempt is allowed in the MVP.

The Student cannot grant or invalidate attempts themselves.
### Blitz Activation Flow

The Teacher activates the Blitz during class.

1. Open the prepared Blitz.
2. Review Topic, recipients, duration, one-normal-attempt rule, and institution timer-start mode.
3. Click **Start / Activate**.
4. The backend validates Teacher scope and task state.
5. Confirm if required.
6. The backend records authoritative activation time and marks the Blitz Active.
7. Assigned Students gain access.
8. For synchronized mode, countdown begins immediately for all assigned Students.
9. For individual mode, each Student's countdown begins when that Student starts.
10. The Teacher opens monitoring.

Teacher activation is required even if a planned/scheduled time exists.
### Student Blitz Access Flow

The Student accesses only an assigned Teacher-activated Blitz.

1. Student opens dashboard/Topic.
2. System checks institution, assignment, Blitz lifecycle, and attempt availability.
3. If not active/assigned, answering is blocked.
4. If active, system checks timer-start mode.
5. In synchronized mode, system calculates remaining time from the shared server deadline.
6. In individual mode, Student presses Start and server creates/starts the attempt with its own deadline.
7. System shows instructions, whole-Blitz remaining time, and attempt state.
8. Student begins answering.

Students cannot access another institution/group/Student's Blitz, bypass closure, or create extra attempts.
### Student Blitz Answering Flow

The Student answers within the authoritative whole-Blitz window.

1. Open active Blitz.
2. See remaining time.
3. Answer questions.
4. System may save in-progress answers when supported.
5. Student may submit before timeout.
6. Explicit submission finalizes and locks the attempt.
7. If time reaches zero first, backend auto-finalizes saved work.
8. Answered items are scored normally.
9. Unanswered items receive zero.
10. Manual-review answers remain waiting for Teacher review.
11. Late writes are rejected.
12. System records whether finalization was explicit or caused by timeout.

An auto-finalized attempt is still a completed submission for scoring when otherwise valid.
### Blitz Monitoring Flow

The Teacher monitors the live Blitz.

The screen may show:

- Student
- Assigned/access state
- Not started / in progress / submitted / auto-finalized
- Remaining or elapsed time
- Normal or exception attempt
- Manual-review status
- Technical issue/exception status
- Score when available

Flow:

1. Teacher opens monitoring.
2. System updates Student states from authoritative server data.
3. Teacher identifies Students with access/start/submission issues.
4. When a valid technical issue is confirmed, Teacher may grant one Student-specific additional attempt with a reason.
5. System preserves the original affected attempt.
6. Monitoring never allows Teacher to answer or edit on behalf of the Student.
### Blitz Submission Recording Flow

After explicit submission or timeout auto-finalization, the system preserves the attempt.

Record at least the relevant:

- Student
- Institution
- Group
- Topic
- Blitz task
- Attempt number
- Normal/exception attempt context
- Started time
- Effective deadline
- Finalized/submitted time
- Finalization reason (explicit or timeout)
- Saved answers
- Review status
- Score when complete
- Approved exception linkage/reason where applicable
- Teacher feedback

The attempt remains historical and is not silently deleted.
### Automatic Blitz Checking Flow

Automatic Blitz checking uses the same approved objective scoring rules as Homework.

1. Finalize the attempt by explicit submit or timeout.
2. Single-choice: all-or-nothing.
3. True / false: all-or-nothing.
4. Multiple-choice: partial credit based on correctly selected options divided by total correct options, with Student selections capped at the number of correct options.
5. Matching: partial credit per correctly matched pair.
6. Ordering: partial credit per correctly positioned item.
7. Fill-in-the-blank: partial credit per correctly completed blank.
8. Short written: automatic only when accepted-answer rules permit.
9. Unanswered timeout items receive zero.
10. If no manual review is required, calculate the Blitz attempt score.
11. If manual review is required, wait until Teacher checking is complete.

Automatic checking does not make an invalid technical-exception attempt official.
### Manual Blitz Checking Flow

Manual Blitz checking applies to answers requiring judgment.

1. The attempt is submitted or auto-finalized.
2. System marks required answers as waiting for Teacher review.
3. Teacher opens the immutable answer/file.
4. Teacher assigns allowed points.
5. Teacher may add feedback.
6. Teacher saves review.
7. System completes the attempt score after all required manual review.
8. If this is the valid normal/exception official attempt, the score becomes available for Topic result calculation.
9. Teacher cannot rewrite the Student answer or directly override the final Topic formula.
### Blitz Score Flow

The official Blitz score comes from the one valid score-bearing Blitz attempt.

1. Complete all automatic/manual scoring.
2. If the normal attempt is valid and no approved exception replaces it, it is official.
3. If the normal attempt was invalidated/excluded under an approved exception, the valid additional attempt is official.
4. Normalize the score to 0–100.
5. Preserve full internal precision.
6. Store the official attempt reference and official Blitz score.
7. Display the score with one decimal place.
8. Use it as `B` in the Topic result formula.

The Teacher cannot manually choose whichever attempt score they prefer outside the approved exception rule.
### Homework and Blitz Comparison Flow

After official Homework and Blitz scores are ready:

1. Verify they belong to the same institution, Student, Topic, and designated official task pair.
2. Use full-precision `H` and `B`.
3. Calculate `D = |H - B|`.
4. Load institution threshold `T`.
5. If `D <= T`, mark consistent and calculate `(H + B) / 2`.
6. If `D > T`, mark inconsistent and use `B`.
7. Do not accuse the Student of cheating based on inconsistency.
8. Assign the category from the derived integer `category_score`.
9. Display scores with one decimal place.

The same rule applies whether Homework or Blitz is higher.
### Blitz Result Review Flow

The Teacher reviews Blitz and Topic result information.

The view may include:

- Student
- Normal/exception attempt status
- Timeout/finalization status
- Official Blitz attempt
- Official Blitz score
- Official Homework score
- Score difference
- Final Topic score
- Understanding category
- Manual review state
- Consistency state
- Feedback

The Teacher uses this information to identify Students needing revision/support and to release results when institution policy requires manual release.
### Student Blitz Result Flow

The Student may view the official Blitz score only according to Student release policy.

1. System completes required checking and determines the official Blitz attempt.
2. Topic result calculation may proceed.
3. Student visibility is checked separately.
4. `automatic` mode releases a fully calculated Topic result automatically.
5. `manual_teacher` mode waits for Teacher release.
6. Once visible, Student sees permitted Blitz/Topic result information with one-decimal score display.

The Student never sees another Student's Blitz data.
### Parent Blitz Result Flow

Parent Blitz result visibility requires an explicit Parent–Student relationship and Student release first.

After Student release:

- `with_student` → Parent result visibility begins automatically.
- `manual_teacher` → Parent waits for separate Teacher release.
- `hidden` → Parent does not receive the result.

When visible, the Parent may view allowed Blitz completion/result information. The Parent cannot interact with the Blitz attempt or modify any assessment data.
### Institution Admin Blitz Overview Flow

Institution Admins may view basic blitz activity inside their own institution.

The Institution Admin blitz overview flow is:

1. The Institution Admin opens institution reports or group progress.
2. The system shows blitz activity inside the institution.
3. The admin reviews blitz completion overview by group, topic, or teacher.
4. The admin identifies groups or students that may need attention.
5. The admin uses the information for management and support.

Institution Admins should not normally answer blitz tasks, change student submissions, manually manipulate scores, or replace the teacher’s checking role.

### Blitz Access and Data Separation Flow

Blitz access requires all applicable checks:

1. Authentication and active user/institution.
2. Same institution.
3. Correct role.
4. Teacher/group/Student assignment.
5. Active Blitz lifecycle when answering.
6. Valid official/supplementary task context.
7. Attempt availability: one normal attempt or one explicitly granted exception.
8. Authoritative timer has not ended when accepting new writes.
9. Result visibility when viewing scores.

Teacher can manage only assigned Blitz tasks. Student can answer only their own assigned Blitz. Parent is read-only. Institution Admin sees institution overview, not Student answer editing. Cross-institution access is blocked.
### Blitz Device Flow

Blitz follows the approved device model:

1. Teacher desktop: create questions, set duration, designate official Blitz, review detailed results.
2. Teacher mobile: activate Blitz, monitor class, grant one approved Student-specific exception, review basic results.
3. Student desktop/mobile: answer active Blitz under the same server timing rules.
4. Parent mobile: view permitted released progress/results.
5. Institution Admin desktop: configure timer-start mode and view overview.
6. Super Admin desktop: platform-level management only.

Changing device never changes attempt, timing, access, or visibility rules.
### Blitz Flow Boundaries

The MVP Blitz flow includes:

- Manual Teacher creation
- Topic connection
- Exactly one designated official result-bearing Blitz per Topic result
- Whole-Blitz duration
- Institution-configured synchronized or individual timer start
- One normal Student attempt
- One optional Student-specific Teacher-approved exception attempt
- Required exception reason
- Historical preservation of affected attempts
- Server-authoritative timing
- Timeout auto-finalization
- Zero for unanswered timeout questions
- Approved partial-credit rules
- Automatic/manual checking
- Official Blitz score
- Homework–Blitz comparison
- Result-release policy
- Access protection

It excludes per-question timers, configurable attempt counts, AI generation, advanced anti-cheating, device monitoring, live competition, QR entry, adaptive difficulty, and advanced real-time analytics.
### MVP Blitz Task Flow Summary

The MVP Blitz Task Flow includes:

1. Teacher creates manual Blitz.
2. Connect it to Topic and authorized recipients.
3. Designate exactly one official Blitz before attempts begin.
4. Set whole-Blitz duration.
5. Apply fixed one-normal-attempt rule.
6. Use institution synchronized or individual timer-start mode.
7. Teacher activates Blitz in class.
8. Student sees authoritative remaining time.
9. Student explicitly submits or is auto-finalized at timeout.
10. Unanswered timeout questions receive zero.
11. Late writes are rejected.
12. Teacher may grant one Student-specific additional attempt for a valid reason.
13. Required exception reason is recorded.
14. Original affected attempt remains in history and is excluded from official scoring.
15. System applies approved objective/partial-credit scoring.
16. Teacher checks manual answers.
17. System identifies official Blitz attempt and score.
18. Official score remains full precision internally and displays with one decimal place.
19. System compares official Homework and Blitz scores.
20. Teacher monitors progress and reviews result.
21. Student/Parent visibility follows approved release modes.
22. Access remains protected by institution, role, group, Student, and relationship.

## 10. Result Calculation Flow

The **Result Calculation Flow** explains how **TestLabUz** converts the official Homework and Blitz scores for one Student and Topic into the final learning result.

The system uses exactly one designated result-bearing Homework and one designated result-bearing Blitz for a Topic result.

The official Homework score is the highest valid completed score from exactly 3 normal Homework attempts. The official Blitz score comes from the valid normal Blitz attempt or, when an approved technical exception replaces the affected attempt, from the one allowed additional Blitz attempt.

Let:

- `H` = official Homework score
- `B` = official Blitz score
- `D = |H - B|`
- `T` = institution acceptable difference threshold

If `D <= T`, final score = `(H + B) / 2`.

If `D > T`, final score = `B`.

Comparison and final-score formula use **unrounded internal values**. Category assignment uses the derived integer `category_score`. User-facing scores are displayed with **one decimal place**.

Result calculation and result visibility are separate. A result may be fully calculated but still hidden from Student and Parent.

### Main Result Calculation Flow

1. The system confirms the designated official Homework and Blitz for the Topic.
2. The system determines the Student's official Homework attempt and score.
3. The system determines the Student's official Blitz attempt and score.
4. The system waits until all required manual checking is complete.
5. The system confirms both scores belong to the same institution, Student, Topic, and official task pair.
6. The system uses full-precision `H` and `B`.
7. The system calculates `D = |H - B|`.
8. The system loads threshold `T`.
9. If `D <= T`, final score = `(H + B) / 2`.
10. If `D > T`, final score = `B`.
11. The system marks consistency/inconsistency.
12. The system assigns understanding category from the derived integer `category_score`.
13. The system saves the result with calculation/rule snapshots and official attempt references.
14. The UI displays numeric scores with one decimal place.
15. The Teacher can review the result immediately within authorized scope.
16. Student visibility follows `automatic` or `manual_teacher`.
17. Parent visibility follows `with_student`, `manual_teacher`, or `hidden`, and can never precede Student release.
18. The Institution Admin may view permitted summaries.
19. Access remains institution/role/relationship scoped.
### Required Scores Flow

The final numeric Topic result requires:

- One designated official Homework for the Topic
- One designated official Blitz for the Topic
- One official Homework score for the Student
- One official Blitz score for the Student
- Completion of required manual checking
- A valid institution threshold `T`
- Valid institution category ranges

Flow:

1. Verify official task pair.
2. Verify Student/Topic/institution consistency.
3. Verify official Homework score readiness.
4. Verify official Blitz score readiness.
5. Verify manual review completion.
6. If all are ready, calculate.
7. Otherwise use an appropriate waiting/not-completed state.

Missing required work never creates an invented numeric score.
### Homework Score Flow

The official Homework score is selected as follows:

1. Student may complete up to 3 normal Homework attempts.
2. Each attempt is scored separately.
3. Required manual review completes before a potentially official attempt is final.
4. Valid completed attempt scores are normalized to 0–100.
5. The system selects the highest valid completed score.
6. That attempt becomes the official Homework attempt.
7. Its unrounded score becomes `H`.
8. Other attempts remain in history.

The Teacher cannot arbitrarily select a lower or different attempt as official.
### Blitz Score Flow

The official Blitz score is determined as follows:

1. Student normally receives one Blitz attempt.
2. If that attempt is valid, it becomes the official Blitz attempt after required checking.
3. If a valid technical/approved issue caused the Teacher to grant the one allowed additional attempt, the original affected attempt remains historical and is excluded from official scoring.
4. The valid additional attempt then becomes the official score-bearing attempt.
5. Required manual review must finish.
6. The score is normalized to 0–100 and preserved without premature rounding.
7. That score becomes `B`.

There is no Teacher-selectable best-of-multiple-Blitz policy.
### Manual Review Waiting Flow

Some homework or blitz answers may require manual checking.

Manual checking may be needed for:

- Open written answers
- File-based assignments
- Short written answers that require teacher judgment
- Any question type that cannot be checked automatically

The manual review waiting flow is:

1. The student submits homework or blitz answers.
2. The system checks whether manual review is needed.
3. If manual review is needed, the system marks the submission as waiting for teacher review.
4. The final result is not calculated yet.
5. The teacher opens submissions waiting for review.
6. The teacher checks the answer.
7. The teacher assigns a score.
8. The teacher adds feedback if needed.
9. The system saves the score.
10. The system checks again whether all required scores are now available.
11. If both homework and blitz scores are available, the system continues to final result calculation.

The final result should not be fully calculated until all required manual checking is complete.

### Score Difference Flow

After both official scores are ready:

1. Take unrounded `H`.
2. Take unrounded `B`.
3. Calculate `D = |H - B|`.
4. Load institution threshold `T`.
5. Compare without display rounding.
6. `D <= T` means consistent.
7. `D > T` means inconsistent.

A displayed rounded number must never change threshold classification.

Inconsistency is educational information, not an automatic cheating accusation.
### Acceptable Score Difference Rule Flow

The acceptable score difference rule defines what “close” and “big difference” mean.

Different institutions may use different rules. One institution may decide that a 10-point difference is acceptable. Another institution may decide that 15 or 20 points is acceptable.

The acceptable score difference rule flow is:

1. The Institution Admin opens result or assessment settings.
2. The admin defines the acceptable score difference.
3. The system saves this rule for the institution.
4. During result calculation, the system checks this rule.
5. If the homework/blitz difference is within the allowed range, the system treats the scores as close.
6. If the difference is bigger than the allowed range, the system treats the scores as very different.

This rule should be configurable because educational institutions may use different grading systems and different assessment approaches.

### Average Score Calculation Flow

When `D <= T`:

1. Confirm official full-precision `H` and `B`.
2. Calculate `(H + B) / 2` without rounding inputs first.
3. Store the full-precision final value.
4. Mark the result consistent.
5. Derive integer `category_score` from the unrounded final value for understanding-category assignment.
6. Display the numeric result with one decimal place.

Example display may show `85.0` even though internal precision rules are preserved.
### Blitz Score as Real Result Flow

When `D > T`:

1. Confirm full-precision `H` and `B`.
2. Mark the result inconsistent.
3. Use full-precision `B` as the final Topic score.
4. Assign the category from the derived integer `category_score`.
5. Display with one decimal place.
6. Show the Teacher the large Homework–Blitz difference without accusing the Student of cheating.

The same rule applies whether `B` is lower or higher than `H`.
### Low Homework and High Blitz Flow

The system should also handle the opposite case: low homework score but high blitz score.

Example:

- Homework score: 45
- Blitz score: 82
- Difference: 37
- Acceptable difference: 10
- Final result: 82

In this case, the blitz score is higher than the homework score. This may mean:

- The student improved after homework.
- The student had a technical problem during homework.
- The student misunderstood the homework task.
- The homework answer was incomplete, but the student understood the topic better during class.

The system should still apply the same rule: if there is a big difference, the blitz score is used as the real result.

The teacher can review the case and decide whether feedback or additional support is needed.

### Final Result Saving Flow

When the result can be calculated, the system saves enough information to preserve its meaning.

At minimum, save:

- Institution
- Student
- Topic
- Designated official Homework
- Designated official Blitz
- Official Homework attempt reference
- Official Blitz attempt reference
- Official `H`
- Official `B`
- `D`
- Threshold `T` used
- Consistency status
- Calculation method
- Full-precision final score
- Understanding category
- Category-range snapshot
- Result calculation status
- Separate Student visibility state
- Separate Parent visibility state
- Relevant release timestamps
- Teacher feedback where applicable

Historical closed results must not silently change because institution settings change later.
### Understanding Category Assignment Flow

After the final score is calculated:

1. Use the **unrounded** final score.
2. Load the institution's current/applicable category ranges.
3. Resolve exactly one of the four numeric categories:
   - Understood well
   - Partially understood
   - Needs revision
   - Needs teacher support
4. Save the category and rule snapshot.
5. Show it to the Teacher.
6. Show it to Student/Parent only according to release policy.

**Not completed** is not a numeric range and is handled from missing required work after valid completion opportunities end.

Display rounding must never move a Student into a different category.
### Not Completed Category Flow

**Not completed** is used only when required work can no longer validly be completed.

1. Check official Homework requirement.
2. Check official Blitz requirement.
3. Check whether required manual review is still pending.
4. Check whether Homework attempts/deadline still allow completion.
5. Check whether Blitz normal/approved exception opportunity is still open.
6. If required work is permanently missing after applicable opportunities end, assign Not completed.
7. Identify whether Homework, Blitz, or both are missing.

Do not use Not completed when:

- Teacher review is pending.
- A valid approved additional Blitz attempt is still available.
- The result is already calculated but not released.
### Result Status Flow

Result calculation status and visibility are separate.

MVP result calculation statuses:

- Waiting for Homework
- Waiting for Blitz task
- Waiting for Teacher review
- Calculated
- Not completed
- Closed

Flow:

1. Missing-but-still-completable Homework → Waiting for Homework.
2. Missing-but-still-completable Blitz → Waiting for Blitz task.
3. Required manual scoring pending → Waiting for Teacher review.
4. Inputs ready and formula/category applied → Calculated.
5. Required work permanently missing → Not completed.
6. Finalized historical result → Closed.

Student and Parent release/visibility must not be encoded by changing these calculation statuses.
### Result Consistency Flow

The system should show whether homework and blitz results are consistent.

The consistency flow is:

1. The system compares homework score and blitz score.
2. The system calculates the score difference.
3. The system checks the acceptable score difference rule.
4. If the difference is within the allowed range, the system marks the result as consistent.
5. If the difference is bigger than the allowed range, the system marks the result as inconsistent.
6. The teacher can use this information to identify students who may need attention.

Possible consistency cases:

- High homework score + high blitz score = strong consistency
- Medium homework score + medium blitz score = normal consistency
- High homework score + low blitz score = possible outside help or weak real understanding
- Low homework score + high blitz score = possible improvement or homework problem
- Missing homework or missing blitz = incomplete learning-check process

The system should show consistency as helpful information, not as an accusation.

### Teacher Result Review Flow

The Teacher reviews all authorized Student Topic results.

The page may show:

- Official Homework and Blitz tasks
- Official attempt references
- Attempt/exception history summary
- Full-precision-derived scores displayed to one decimal
- Score difference
- Threshold used
- Consistency
- Final score
- Understanding category
- Calculation status
- Student visibility
- Parent visibility
- Manual review status
- Feedback

If an underlying manual scoring error is corrected before closure, the system recalculates the dependent result. The Teacher cannot directly type a replacement final result.

The Teacher also performs manual release actions where institution policy requires them.
### Student Result Viewing Flow

Student result visibility follows institution policy.

1. System completes result calculation.
2. Calculation status becomes Calculated.
3. Student visibility is evaluated separately.
4. If Student mode is `automatic`, release occurs automatically.
5. If Student mode is `manual_teacher`, the result remains hidden until the authorized Teacher releases it.
6. When visible, Student sees own official Homework score, official Blitz score, final score, category, completion state, and allowed feedback.
7. Scores display with one decimal place.

Hidden does not mean incomplete.
### Parent Result Viewing Flow

Parent result visibility always requires Student release first.

1. Parent opens connected child's result.
2. System verifies the relationship.
3. System confirms Student result is released.
4. System evaluates Parent mode:
   - `with_student`: release follows Student release automatically.
   - `manual_teacher`: require separate authorized Teacher release.
   - `hidden`: do not expose the result.
5. When visible, Parent sees allowed score/category/progress information.
6. Parent remains read-only.

The Parent can never receive the result before the Student.
### Institution Admin Result Overview Flow

The Institution Admin may view general result information inside their own institution.

The Institution Admin result overview flow is:

1. The Institution Admin opens institution reports.
2. The system shows result summaries inside the institution.
3. The admin views group-level result overview.
4. The admin views topic-level result overview.
5. The admin views understanding category distribution.
6. The admin identifies groups or students that may need attention.
7. The admin uses the information for management and support.

Institution Admins should not normally change student answers, manually manipulate scores, or replace the teacher’s checking role.

### Super Admin Result Boundary Flow

The Platform Owner / Super Admin may view platform-level statistics, but should not normally interfere with institution-level learning results.

The Super Admin result boundary flow is:

1. The Super Admin opens platform-level reports or statistics.
2. The system shows general platform information.
3. The Super Admin may see institution activity summaries.
4. The Super Admin does not normally change student results.
5. The Super Admin may support institution-level issues only when needed for support, security, or system management.

The Super Admin should not usually:

- Change homework scores
- Change blitz scores
- Change final results
- Change understanding categories
- Edit student submissions
- Replace teacher checking
- Interfere with daily class results

This keeps learning results under the correct institution and teacher control.

### Result Access and Data Separation Flow

Result access requires institution, role, group/Student relationship, and visibility checks.

- Teacher: assigned Student results, including calculated-but-unreleased results.
- Student: only own results after Student release.
- Parent: only connected child results after Student release and Parent visibility approval.
- Institution Admin: permitted summaries inside own institution.
- Super Admin: platform-level statistics/support boundary, not routine educational result editing.
- Cross-institution access: always blocked.

A direct URL or identifier never bypasses these rules.
### Result Device Flow

The result calculation flow should follow the approved device access model.

The device flow is:

1. Teachers use desktop to review detailed result tables, score differences, final scores, categories, and reports.
2. Teachers may use mobile to view basic result summaries and identify students who need support.
3. Students use desktop or mobile to view their own released results.
4. Parents use mobile to view their child’s released results and understanding categories.
5. Institution Admins use desktop to view institution-level result summaries and reports.
6. Super Admins use desktop to view platform-level statistics.

Each device version should show only the result information that matches the user’s role and access level.

### Result Calculation Boundaries

The MVP result engine supports only the approved rule:

- One official Homework + one official Blitz per Topic result
- Highest valid completed Homework attempt
- Valid normal/approved-exception Blitz attempt
- Full-precision internal calculation
- `D = |H - B|`
- Institution-configured `T`
- Average when `D <= T`
- Blitz when `D > T`
- Category from derived integer `category_score`
- One-decimal display
- Separate calculation and visibility
- Student release modes: automatic/manual Teacher
- Parent modes: with Student/manual Teacher/hidden
- Historical rule snapshots

The MVP does not include custom formulas, direct Teacher final-score overrides, AI predictions, advanced appeals, or formal grading approval chains.
### MVP Result Calculation Flow Summary

The MVP Result Calculation Flow includes:

1. Identify designated official Homework and Blitz pair.
2. Select highest valid completed Homework attempt as official.
3. Select valid official Blitz attempt, including approved exception when applicable.
4. Wait for required manual review.
5. Verify same Student/Topic/institution context.
6. Use unrounded official scores.
7. Calculate absolute difference.
8. Apply institution threshold.
9. Average when `D <= T`.
10. Use Blitz when `D > T`.
11. Record consistency without automatic cheating accusation.
12. Assign category using derived integer `category_score`.
13. Display scores with one decimal place.
14. Store calculation method and rule snapshots.
15. Keep result calculation status separate from visibility.
16. Support automatic/manual Student release.
17. Support with-Student/manual/hidden Parent visibility.
18. Never release Parent result before Student release.
19. Support waiting and Not completed correctly.
20. Protect result access by institution/role/relationship.
21. Preserve closed historical results.

## 11. Access and Permission Flow

The **Access and Permission Flow** explains how **TestLabUz** decides what each user is allowed to view, create, edit, manage, submit, or change.

Access control is an essential part of the platform because **TestLabUz** will support many educational institutions from the beginning. Every institution will have its own users, groups, topics, materials, homework assignments, blitz tasks, submissions, results, settings, and reports.

Users from one institution must not be able to access data from another institution.

The main access rule in **TestLabUz** is:

**Each user can only access data and actions inside their allowed scope.**

A user’s allowed scope depends on:

- User role
- Educational institution
- Assigned group or class
- Assigned topic or task
- Teacher-group relationship
- Student-group relationship
- Parent-child relationship
- Record ownership
- Specific permission
- User and institution status

The MVP version should keep the permission model simple but correct. Advanced custom roles and enterprise security features can be added later, but institution separation and role boundaries must work correctly from the first version.

### Main Access and Permission Flow

The main access and permission flow is:

1. The user logs in to the platform.
2. The system verifies the user account.
3. The system checks whether the user account is active.
4. The system checks whether the user’s institution is active.
5. The system identifies the user’s role.
6. The system identifies the user’s institution.
7. The system loads the permissions connected to the role.
8. The system checks the user’s group, student, teacher, or parent relationships.
9. The user tries to open a page, record, file, task, submission, result, or report.
10. The system checks whether the requested action is allowed.
11. If access is allowed, the system opens the requested information or action.
12. If access is not allowed, the system blocks the request.
13. The system shows a clear access or permission message.
14. The user continues working only inside the allowed scope.
15. The same permission rules remain active on desktop and mobile.

This flow should protect every important part of the system.

### Authentication Flow

The access process begins when the user logs in.

The authentication flow is:

1. The user opens the login page.
2. The user enters their login information.
3. The user submits the login form.
4. The system validates the provided information.
5. The system finds the related user account.
6. The system checks whether the account is active.
7. The system checks whether the user’s institution is active.
8. If the login information and account status are valid, the system allows access.
9. The system identifies the user’s role and institution.
10. The system opens the correct dashboard.
11. If login is unsuccessful, the system shows a clear error message.

The system should support basic account security in the MVP, including:

- Login
- Logout
- Password protection
- Active or inactive user status
- Role-based access
- Institution-based access

Every user should use their own account. One user should not use another person’s account because permissions, submissions, results, and actions are connected to the authenticated user.

### Role Identification Flow

After login, the system should identify the user’s role.

The MVP roles are:

1. Platform Owner / Super Admin
2. Institution Admin
3. Teacher
4. Student
5. Parent

The role identification flow is:

1. The user logs in successfully.
2. The system reads the user’s assigned role.
3. The system loads the permissions for that role.
4. The system opens the correct role dashboard.
5. The system shows only navigation items and actions allowed for that role.
6. The system hides or disables actions that are not allowed.
7. If the user manually tries to open a restricted page, the system checks permission again and blocks access.

The interface should not be the only protection. Even if a restricted button or link is hidden, the system must still check permissions when the user tries to open or change data.

### Institution Scope Flow

Every institution-level user and record should belong to the correct institution.

The institution scope flow is:

1. The system identifies the user’s institution.
2. The user requests a page, list, record, file, task, submission, result, or report.
3. The system checks which institution owns that data.
4. The system compares the data’s institution with the user’s institution.
5. If both belong to the same institution and role permissions allow access, the system continues.
6. If they belong to different institutions, the system blocks access.
7. The system shows a clear data-separation message.

Institution-based data separation should protect:

- Institution profiles
- Users
- Teachers
- Students
- Parents
- Groups or classes
- Topics
- Learning materials
- Homework assignments
- Blitz tasks
- Student submissions
- Submitted files
- Homework scores
- Blitz scores
- Final results
- Understanding categories
- Reports
- Institution settings

For example, a teacher from Institution A must not access students, topics, assignments, or results from Institution B.

### Platform Owner / Super Admin Access Flow

The Platform Owner / Super Admin has platform-level access.

The Super Admin access flow is:

1. The Super Admin logs in.
2. The system verifies the Super Admin role.
3. The system opens the platform dashboard.
4. The Super Admin can view and manage educational institutions.
5. The Super Admin can create institutions.
6. The Super Admin can edit basic institution information.
7. The Super Admin can activate or deactivate institutions.
8. The Super Admin can view basic platform statistics.
9. The Super Admin can manage basic global settings.
10. The Super Admin can support Institution Admins when needed.

The Super Admin should not normally interfere with daily educational data.

The Super Admin should not usually:

- Complete homework for students
- Answer blitz tasks
- Change student answers
- Change homework submissions
- Change blitz submissions
- Change homework scores
- Change blitz scores
- Change final results
- Edit teacher-created learning content
- Replace the Teacher role
- Replace the Institution Admin’s daily management role

The Super Admin may access or support institution-level information only when there is a valid support, security, or system-management reason.

### Institution Admin Access Flow

The Institution Admin manages only their own institution.

The Institution Admin may:

1. Manage Teachers, Students, Parents, groups, assignments, and relationships at the management/overview level permitted by role.
2. Configure understanding-category ranges.
3. Configure acceptable Homework–Blitz threshold.
4. Configure institution Blitz timer-start mode.
5. Configure Student result-release mode.
6. Configure Parent result-visibility mode.
7. Configure institution IANA timezone.
8. Configure lower upload limits within platform hard maximums.
9. View basic institution reports.

The Institution Admin does **not** configure Homework/Blitz attempt counts. Those are fixed by the MVP.

The Institution Admin cannot access another institution or routinely edit Student submissions, manually manipulate scores, or replace Teacher checking.
### Teacher Access Flow

The Teacher can manage only assigned groups, Students, Topics, tasks, submissions, and results.

Authorized Teacher actions include:

- Create/manage own Topic content.
- Upload materials within effective limits.
- Create Homework and Blitz tasks.
- Designate one official Homework and one official Blitz before attempts begin.
- Set Homework deadline and whole-Blitz duration.
- Activate Blitz.
- Grant one Student-specific additional Blitz attempt for a valid reason.
- Check manual answers.
- Correct underlying manual scoring before result closure.
- Review calculated results.
- Release Student/Parent results when institution policy requires Teacher action.

Before each action, the backend checks institution, group assignment, task ownership, Student scope, lifecycle, and specific permission.

The Teacher cannot change institution-wide learning settings, configure arbitrary attempt counts, grant more than one Blitz exception per Student, or directly override the final Topic formula.
### Student Access Flow

The Student can access only learning content and tasks assigned to them.

The Student access flow is:

1. The student logs in.
2. The system identifies the student’s institution.
3. The system identifies the student’s group or groups.
4. The system loads topics assigned to those groups or directly to the student.
5. The student opens an assigned topic.
6. The system checks that the topic belongs to the student’s allowed scope.
7. The student can open assigned learning materials.
8. The student can complete assigned homework.
9. The student can answer an assigned blitz task only when it is active.
10. The student can view only their own submissions and released results.

Students must not be able to:

- View other students’ answers
- View other students’ scores
- View other students’ progress
- Open unrelated topics
- Complete another student’s task
- Create official topics
- Upload official learning materials
- Create assignments
- Create blitz tasks
- Start or activate blitz tasks
- Check answers
- Change scores
- Manage users
- Manage groups
- Change institution settings
- Access another institution’s data

The system should also block new submissions when task rules no longer allow them.

### Parent Access Flow

The Parent can access only permitted progress for explicitly connected children.

1. Parent logs in.
2. System verifies institution and Parent–Student relationships.
3. Parent selects a connected child.
4. System shows allowed non-sensitive progress.
5. Result values require Student release first.
6. Parent mode then applies:
   - `with_student`
   - `manual_teacher`
   - `hidden`
7. Parent remains read-only.

Knowing a Student ID or direct URL never grants access.
### Group-Based Access Flow

Groups or classes are an important part of access control.

The group-based access flow is:

1. A teacher, student, or admin tries to open group-related data.
2. The system identifies the requested group.
3. The system checks the group’s institution.
4. The system checks the user’s relationship with the group.
5. If the user is allowed, the system opens the group data.
6. If the user is not connected to the group, the system blocks access.

Group access should work like this:

- Institution Admins can manage groups inside their own institution.
- Teachers can access groups assigned to them.
- Students can access learning content assigned to their groups.
- Parents can view their child’s progress inside the child’s group context.
- Users from another institution cannot access the group.

A teacher assigned to Group A should not automatically access Group B.

### Parent-Child Relationship Access Flow

The parent-child connection should control all parent progress access.

The parent-child relationship flow is:

1. The Institution Admin connects a parent to a student.
2. The system saves the relationship.
3. The parent logs in.
4. The system loads only connected students.
5. The parent selects a connected child.
6. The system shows allowed progress information for that child.
7. If the relationship is removed, the parent loses access to that child’s progress.
8. If the parent tries to open an unrelated student, the system blocks access.

The system may support:

- One parent connected to one student
- One parent connected to multiple students
- One student connected to one or more parents

Each relationship must remain inside the correct institution.

### Topic and Learning Material Access Flow

Topics and learning materials should be protected by institution, group, and role permissions.

The topic and material access flow is:

1. A user tries to open a topic.
2. The system checks the topic’s institution.
3. The system checks the topic’s group.
4. The system checks the user’s role and relationship.
5. If access is allowed, the system shows the topic.
6. The user tries to open a learning material.
7. The system checks material permission.
8. If allowed, the system opens or downloads the file.
9. If not allowed, the system blocks access.

Topic and material access should work like this:

- Teachers can manage materials for their own topics.
- Students can open materials assigned to them.
- Institution Admins may view topic activity inside their own institution for management purposes.
- Parents may view basic topic progress if allowed, but should not manage materials.
- Users from another institution must not access topic materials.

Knowing or copying a file address should not give a user permission to access the file.

### Homework Assignment Permission Flow

Homework permission checks protect creation, attempt use, submission, checking, and result access.

1. Teacher creates Homework in assigned scope.
2. System applies fixed 3 normal attempts.
3. Teacher may designate one official Homework before attempts begin.
4. Student opening Homework must be assigned and inside same institution.
5. Backend checks lifecycle, deadline, and remaining normal attempts.
6. Student submits only their own attempt.
7. A fourth normal attempt is blocked.
8. Teacher reviews only assigned Student submissions.
9. Student result visibility follows Student release.
10. Parent visibility follows Parent release policy.

Cross-institution, unrelated-group, draft/closed, expired-deadline, and attempt-exhausted writes are blocked.
### Blitz Task Permission Flow

Blitz permission checks include assignment, lifecycle, timing, and exception-attempt authority.

1. Teacher creates Blitz in assigned scope.
2. Teacher designates one official Blitz before attempts begin if it is result-bearing.
3. Student cannot answer before Teacher activation.
4. Backend checks institution, group/Student assignment, Active status, timer-start mode, authoritative deadline, and attempt availability.
5. Normal Student allowance is one Blitz attempt.
6. Only an authorized Teacher may grant one additional Student-specific attempt for a valid reason.
7. Teacher must record the reason.
8. No third Blitz attempt is allowed.
9. At timeout, backend auto-finalizes saved work and blocks late writes.
10. Teacher reviews only assigned submissions.
11. Result viewing follows release rules.

Draft, scheduled-before-activation, closed, archived, unrelated, expired, or exhausted Blitz writes are blocked.
### Submission Protection Flow

Student submissions should be protected from unauthorized viewing or editing.

The submission protection flow is:

1. The student submits homework or blitz answers.
2. The system connects the submission to the correct student, institution, group, topic, and task.
3. The system records the attempt and submission time.
4. The student may view their own submission according to task rules.
5. The teacher may review the submission if the student belongs to an assigned group.
6. Parents may view completion or result information if allowed, but not edit the submission.
7. Institution Admins may view activity summaries, but should not normally change student answers.
8. Other students and unrelated users cannot access the submission.

The system should prevent unauthorized changes after:

- The student submits the final answer
- The task closes
- The deadline passes
- The time limit ends
- All attempts are used
- The teacher completes checking
- The system rules no longer allow editing

### File Access Protection Flow

Uploaded learning materials and Student submission files are protected by the same ownership/scope checks as their records.

Platform hard maximums:

- Learning material: **25 MB per file**
- Student submission: **15 MB per file**

An Institution Admin may configure lower limits.

Flow:

1. User uploads or requests a file.
2. System identifies connected institution/Topic/task/Student record.
3. Backend checks authorization.
4. Uploads are authoritatively validated for type and effective size limit.
5. If allowed, file access/upload proceeds.
6. Otherwise it is blocked.

Direct file addresses must not bypass authorization. Failed or invalid uploads must not become valid learning materials or answers.
### Score and Result Access Flow

Scores/results are private educational data.

1. System calculates/stores scores and result state.
2. Teacher may view assigned results even before Student release.
3. Student may view only own result after Student release.
4. Parent may view only connected child result after Student release and according to Parent mode.
5. Institution Admin may view permitted own-institution summaries.
6. Super Admin remains within platform/support boundary.
7. Other access is blocked.

Protected data includes official Homework/Blitz attempts, scores, difference, threshold snapshot, final score, category, visibility state, feedback, and consistency.
### Report Permission Flow

Reports should use the same access rules as the underlying data.

The report permission flow is:

1. A user opens the reports section.
2. The system identifies the user’s role and scope.
3. The system loads only reports allowed for that scope.
4. The user applies filters.
5. The system ensures that filters do not expose unauthorized data.
6. The system shows the allowed report.
7. Attempts to open restricted details are blocked.

Report access should work like this:

- Super Admin sees basic platform-level reports.
- Institution Admin sees only their institution’s reports.
- Teacher sees only assigned groups and students.
- Student sees only personal progress.
- Parent sees only connected child progress.

A report filter must not allow a teacher, student, or parent to access data that they could not access directly.

### View and Edit Permission Flow

The system should clearly separate viewing information from changing information.

The view and edit permission flow is:

1. A user opens a record.
2. The system checks view permission.
3. If view permission is allowed, the system shows the record.
4. The user tries to edit the record.
5. The system checks edit permission separately.
6. If edit permission is allowed, the system accepts the change.
7. If edit permission is not allowed, the system blocks the change.

Examples:

- A parent may view a child’s result but cannot edit it.
- A student may view their own score but cannot change it.
- A teacher may review assigned student results but cannot manage institution-wide settings.
- An Institution Admin may manage users and settings but should not change student submissions.
- A Super Admin may manage institutions but should not normally change daily educational data.

Having permission to view something does not automatically mean the user can edit it.

### Protected Action Flow

Important protected actions include:

- User/group/relationship management
- Institution learning-setting changes
- Category-range changes
- Acceptable score-difference threshold changes
- Blitz timer-start mode changes
- Student/Parent release-policy changes
- Institution timezone changes
- Upload-limit changes
- Topic/material creation and editing
- Homework/Blitz creation
- Official result-bearing pair designation
- Homework deadline changes
- Blitz duration changes
- Blitz activation/closure
- Starting/submitting attempts
- Granting the one additional Student-specific Blitz attempt
- Manual scoring and feedback
- Allowed underlying score correction/recalculation
- Student result release
- Parent result release
- Report access
- Institution activation/deactivation

Each action must pass authentication, role, institution, relationship/ownership, lifecycle, and specific permission checks. UI visibility is not sufficient authorization.
### User Activation and Deactivation Flow

The system should support active and inactive user accounts.

The user status flow is:

1. An authorized admin opens a user account.
2. The admin activates or deactivates the user.
3. The system saves the new account status.
4. If the user is active, the user can access the platform according to role permissions.
5. If the user is inactive, the user cannot use the platform normally.
6. When the user tries to log in or continue using the platform, the system blocks access.
7. The system shows an account-status message.
8. If an authorized admin activates the user again, normal role-based access is restored.

Deactivating a user should not remove historical topics, submissions, scores, or reports. The account should become unavailable while existing records remain connected for history.

### Institution Activation and Deactivation Flow

Institution status should affect every user inside that institution.

The institution status flow is:

1. The Super Admin opens the institution details page.
2. The Super Admin activates or deactivates the institution.
3. The system saves the institution status.
4. If the institution is active, its users can use the platform according to their roles.
5. If the institution is inactive, users from that institution cannot continue using the platform normally.
6. When an institution user tries to log in or open protected data, the system blocks access.
7. The system shows an institution-status message.
8. If the institution is activated again, normal role-based access is restored.

Institution deactivation should not mix, delete, or transfer the institution’s data to another institution.

### Record Ownership and Relationship Flow

Every important record remains connected to the correct context:

- User → institution
- Group → institution
- Teacher → institution + assigned groups
- Student → institution + groups
- Parent → institution + connected Students
- Topic → institution + Teacher + group
- Material → Topic
- Homework → Topic + recipients + result-bearing designation
- Blitz → Topic + recipients + result-bearing designation
- Attempt → Student + task + attempt number
- Blitz exception → Student + affected attempt + Teacher + reason
- Official task score → official attempt
- Topic result → Student + Topic + official Homework/Blitz pair
- Visibility → Topic result + Student/Parent release state

These relationships drive access checks, historical integrity, and result calculation.
### Permission Denial Flow

If a user tries to access information or perform an action outside the allowed scope, the system should block the request.

The permission denial flow is:

1. The user requests a restricted page, record, file, or action.
2. The system checks permissions and scope.
3. One or more checks fail.
4. The system does not show protected information.
5. The system does not perform the requested change.
6. The system shows a clear message.
7. The user can return to an allowed page.

Example messages:

- “You do not have permission to access this page.”
- “This task is not assigned to you.”
- “This group is not assigned to you.”
- “This blitz task is not active.”
- “This task is closed.”
- “No further attempt is available for this task.”
- “You cannot access another student’s result.”
- “This student is not connected to your account.”
- “You cannot access data from another institution.”
- “You cannot edit this record.”
- “Your account is inactive.”
- “Your institution is inactive.”

Permission messages should be clear without revealing private information about restricted records.

### Device Permission Consistency Flow

Permissions should remain the same across desktop and mobile devices.

The device permission flow is:

1. A user logs in from desktop or mobile.
2. The system identifies the same account, role, institution, and relationships.
3. The system shows device-appropriate features.
4. The user tries to access a page or action.
5. The system applies the same permission rules used on every device.
6. Restricted data remains restricted even if the user changes devices.

For example:

- A student using desktop still cannot view another student’s scores.
- A student using mobile still cannot answer an inactive blitz task.
- A parent using mobile still cannot change learning results.
- A teacher using mobile still cannot access unrelated groups.
- An Institution Admin using desktop still cannot access another institution’s data.

Device differences should affect the interface, not the user’s security scope.

### Access Flow Boundaries

The MVP Access and Permission Flow should stay simple but correct.

The MVP should not include:

- Custom user-created roles
- Advanced permission groups
- Two-factor authentication
- Advanced session management
- Device management
- IP restrictions
- Suspicious activity detection
- Enterprise identity integration
- Advanced audit reports
- Complex temporary access rules
- Advanced file scanning
- Impersonation tools
- Complex department-level permission structures

These features may be added later when the platform grows.

In the MVP, access control should mainly support:

- Secure login and logout
- Five approved roles
- Institution-based data separation
- Group-based access
- Teacher-assigned group access
- Student-assigned task access
- Parent-child access
- View and edit separation
- Protected actions
- File protection
- Submission protection
- Score and result protection
- Report protection
- Active and inactive users
- Active and inactive institutions
- Clear permission messages

### MVP Access and Permission Flow Summary

In the MVP version, the Access and Permission Flow should include:

1. Authenticate users through login.
2. Allow users to log out.
3. Check active or inactive user status.
4. Check active or inactive institution status.
5. Identify the user’s role.
6. Apply role-based access control.
7. Separate data by institution.
8. Protect group-based access.
9. Allow teachers to access only assigned groups.
10. Allow students to access only assigned topics and tasks.
11. Allow parents to access only connected children.
12. Protect Platform Owner / Super Admin pages.
13. Protect Institution Admin pages.
14. Protect Teacher pages and actions.
15. Protect Student pages and submissions.
16. Protect Parent progress access.
17. Separate view permissions from edit permissions.
18. Protect important management actions.
19. Protect learning materials.
20. Protect submitted assignment files.
21. Protect homework submissions.
22. Protect blitz submissions.
23. Protect scores and final results.
24. Protect understanding categories.
25. Protect reports by role and scope.
26. Block access to another institution’s data.
27. Block access to unrelated group data.
28. Block students from viewing other students’ data.
29. Block parents from viewing unrelated children’s data.
30. Block unauthorized changes after deadlines, time limits, task closure, or used attempts.
31. Keep every record connected to the correct institution.
32. Keep topics connected to the correct group and teacher.
33. Keep assignments connected to the correct topic.
34. Keep blitz tasks connected to the correct topic and group.
35. Keep results connected to the correct student.
36. Keep parents connected only to allowed children.
37. Show clear permission error messages.
38. Apply the same access rules on desktop and mobile.

The main purpose of the Access and Permission Flow is to make sure every user works only inside the correct role, institution, group, topic, student, and parent-child context. This protects institution data, student privacy, learning content, submissions, scores, results, and the overall reliability of **TestLabUz**.

## 12. MVP Flow Scope and Future Flow Improvements

The **MVP Flow Scope and Future Flow Improvements** section defines which user flows should be included in the first version of **TestLabUz** and which flows should be improved or added later.

The purpose of the MVP is to build a simple, practical, usable, and reliable version of the platform that proves the core business idea:

Teachers can create topics, upload learning materials, assign homework, give short blitz tasks during class, compare homework and blitz results, and understand the student’s real learning level.

The MVP should support the complete core learning-check process from beginning to end, but it should not try to include every possible educational workflow from the beginning.

The first version should focus only on flows that are necessary for:

- Managing educational institutions
- Managing the five approved user roles
- Organizing groups and user relationships
- Creating topics and learning materials
- Creating and completing homework
- Creating and completing blitz tasks
- Checking student submissions
- Calculating final results
- Showing understanding categories
- Monitoring basic learning progress
- Protecting institution and student data

Future flows should be added step by step after the MVP is completed, tested with real users, and improved based on real institutional needs.

### Main MVP Flow Principle

The main MVP flow principle is:

**Every included flow must directly support the core learning-check process or the basic management required to make that process work.**

A flow should be included in the MVP when it is necessary for one of the following reasons:

- It allows the platform to support multiple institutions.
- It gives one of the five approved roles the minimum required access.
- It allows teachers to create and manage the learning process.
- It allows students to study and complete assigned tasks.
- It allows parents to monitor their child’s progress.
- It allows the system to compare homework and blitz performance.
- It protects users, institutions, submissions, files, and results.
- It makes the complete process usable from beginning to end.

A flow should be left for a future version when:

- It is not required for the core learning-check process.
- It makes the MVP significantly more complex.
- It depends on AI, external services, payments, or advanced infrastructure.
- It requires advanced customization that has not yet been validated.
- It can be added later without changing the main product idea.
- Its real value should first be confirmed through user feedback.

### Main MVP End-to-End Flow

The end-to-end MVP flow is:

1. Super Admin creates/activates an institution.
2. Institution Admin creates Teachers, Students, Parents, groups, and relationships.
3. Institution Admin configures category ranges, acceptable score-difference threshold, Blitz timer-start mode, result-release modes, timezone, and optional lower upload limits.
4. Teacher creates a Topic.
5. Teacher uploads supported learning materials within the effective 25 MB limit.
6. Teacher creates one or more Homework tasks. Practice Homework may target the whole group or selected Students, but the official result-bearing Homework must target the whole group.
7. When the first task in the official pair becomes active, the system snapshots the current eligible Topic-group Students as the official cohort; Student studies materials and receives exactly 3 normal Homework attempts.
8. System/Teacher checks Homework attempts using approved scoring rules.
9. Highest valid completed Homework score becomes official.
10. Teacher creates one or more Blitz tasks. Practice Blitz may target selected Students, but the official result-bearing Blitz must target the whole group and reuse the same official Topic cohort.
11. Teacher sets whole-Blitz duration and activates the official Blitz during class.
12. Institution synchronized/individual timer-start mode applies.
13. Student normally receives one Blitz attempt.
14. Student submits before timeout or system auto-finalizes saved work at timeout.
15. Unanswered timeout questions receive zero.
16. Teacher may grant one additional Student-specific Blitz attempt for a valid technical/approved reason.
17. System/Teacher completes Blitz checking.
18. System identifies official Blitz score.
19. System compares unrounded official Homework and Blitz scores.
20. System applies threshold formula.
21. System derives integer `category_score` and assigns the category from it.
22. UI displays numeric scores with one decimal place.
23. Teacher reviews result.
24. Student result release follows automatic/manual Teacher mode.
25. Parent result visibility follows with-Student/manual Teacher/hidden mode and never precedes Student release.
26. Institution Admin views permitted summaries.
27. System preserves institution separation and historical records.

If this flow works reliably, the MVP proves the core TestLabUz concept.
### MVP Platform Owner / Super Admin Flow Scope

The Platform Owner / Super Admin flow in the MVP should focus on basic platform and institution management.

The MVP should include these Super Admin flows:

1. Log in as Platform Owner / Super Admin.
2. Open the platform dashboard.
3. View the list of educational institutions.
4. Create an educational institution.
5. View institution details.
6. Edit basic institution information.
7. Activate an institution.
8. Deactivate an institution.
9. View basic institution status.
10. View basic institution usage information.
11. View simple platform statistics.
12. Support Institution Admin access when needed.
13. Manage limited global platform settings.
14. Block unauthorized users from platform-management pages.
15. Log out.

The Super Admin flow should remain platform-focused.

The MVP should not require the Super Admin to manage daily classroom activity, student submissions, homework scores, blitz scores, or individual learning results.

Advanced Super Admin flows such as billing, subscription management, storage plans, licensing, support-team workflows, advanced platform analytics, and detailed audit reporting should be added later.

### MVP Institution Admin Flow Scope

The MVP Institution Admin flow includes:

1. Login and institution dashboard.
2. Manage institution profile within allowed fields.
3. Manage Teacher, Student, Parent accounts.
4. Manage groups/classes.
5. Assign Students/Teachers to groups.
6. Connect Parents to Students.
7. Configure acceptable Homework–Blitz threshold.
8. Configure understanding-category ranges.
9. Configure synchronized or individual Blitz timer-start mode.
10. Configure Student result release: automatic/manual Teacher.
11. Configure Parent result visibility: with Student/manual Teacher/hidden.
12. Configure institution IANA timezone.
13. Configure lower upload limits within 25 MB/15 MB platform maximums.
14. View basic group/Student/institution reports.
15. Remain inside own institution.
16. Log out.

Attempt counts are not Institution Admin settings in the MVP.
### MVP Teacher Flow Scope

The MVP Teacher flow includes:

1. Login/dashboard/assigned groups.
2. Create/manage Topics.
3. Upload supported learning materials within the effective 25 MB limit.
4. Create Homework with nine question types.
5. Apply fixed 3 Homework attempts.
6. Set optional institution-local Homework deadline.
7. Designate one official Homework before attempts begin.
8. Review Homework attempts and manual answers.
9. Create manual Blitz.
10. Set whole-Blitz duration.
11. Designate one official Blitz before attempts begin.
12. Activate Blitz.
13. Monitor synchronized/individual timer behavior.
14. Grant one Student-specific additional Blitz attempt for a valid reason.
15. Review auto-finalized/explicit Blitz submissions.
16. Apply manual scoring where needed.
17. Review official Homework/Blitz scores and final results.
18. Release Student/Parent results when institution policy requires Teacher action.
19. View Topic/group/Student progress.
20. Use desktop for detailed work and mobile for quick classroom actions.
21. Stay inside assigned scope.

Teacher cannot configure arbitrary attempt counts or directly override final Topic formula.
### MVP Student Flow Scope

The MVP Student flow includes:

1. Login/dashboard.
2. View assigned Topics/materials.
3. View Homework deadline in institution local time.
4. Receive exactly 3 normal Homework attempts.
5. Submit separate Homework attempts, or have an in-progress Attempt auto-finalized from saved work at the authoritative Homework deadline.
6. Receive zero for unanswered Homework components when deadline auto-finalization occurs; any unused remaining Homework attempts become unavailable.
7. Upload supported answer files within effective 15 MB limit.
8. Have highest valid completed Homework score selected as official.
9. Access Blitz only after Teacher activation.
10. Follow synchronized/individual timer-start behavior.
11. Receive one normal Blitz attempt.
12. Receive at most one Teacher-approved extra Blitz attempt for a valid reason.
13. See whole-Blitz remaining time.
14. Submit before timeout or be auto-finalized at timeout.
15. Receive zero for unanswered timeout questions.
16. Wait for Teacher review where needed.
17. Receive approved objective partial credit.
18. View result only after Student release.
19. See released numeric scores with one decimal place.
20. View category/progress/feedback when allowed.
21. Use desktop/mobile as appropriate.
22. Remain inside own data scope.
### MVP Parent Flow Scope

The MVP Parent flow includes:

1. Login from mobile.
2. View connected child/children.
3. View allowed Topic/task completion progress.
4. Never receive result values before Student release.
5. Support `with_student` visibility.
6. Support `manual_teacher` visibility.
7. Support `hidden` visibility.
8. View released official Homework score.
9. View released official Blitz score.
10. View released final score/category.
11. View allowed Teacher feedback.
12. Identify Topics needing revision/support.
13. Remain read-only and restricted to connected children.
### MVP Topic Learning Flow Scope

The MVP Topic flow includes:

1. Create Topic in assigned institution/group scope.
2. Add basic Topic information.
3. Upload supported materials.
4. Allow multiple Homework tasks.
5. Designate exactly one official Homework before attempts begin.
6. Allow multiple Blitz tasks.
7. Designate exactly one official Blitz before attempts begin.
8. Preserve the designated pair once Student attempts begin.
9. Record official Homework/Blitz scores.
10. Calculate one final Topic result per Student.
11. Assign category.
12. Apply Student/Parent visibility policies.
13. Review progress.
14. Close/archive while preserving history.
15. Protect access.
### MVP Learning Material Flow Scope

The MVP learning-material flow includes:

1. Teacher selects assigned Topic.
2. Teacher chooses PDF, DOCX, PPT, or PPTX.
3. System shows effective upload limit.
4. Platform hard maximum is 25 MB per file.
5. Backend validates type/size/scope.
6. Valid file is connected to Topic.
7. Teacher may manage it according to lifecycle rules.
8. Assigned Students may open/download it.
9. Unauthorized access is blocked.

Audio/video, collaborative editing, AI summaries, and external cloud-storage integration remain outside MVP.
### MVP Homework Assignment Flow Scope

The MVP Homework flow includes:

1. Teacher creates Homework for Topic.
2. Designate one official result-bearing Homework before attempts begin.
3. Apply exactly 3 normal attempts per Student.
4. Show current/remaining attempts.
5. Store each attempt separately.
6. Set optional institution-local deadline with UTC authoritative enforcement.
7. Support nine question types.
8. Apply approved objective/partial-credit scoring.
9. Support Teacher manual review.
10. Support Student files up to effective 15 MB limit.
11. Select highest valid completed attempt as official.
12. Preserve full internal score precision and display one decimal.
13. Feed official score into Topic result.
14. Protect access/history.
### MVP Blitz Task Flow Scope

The MVP Blitz flow includes:

1. Teacher creates manual Blitz.
2. Designate one official result-bearing Blitz before attempts begin.
3. Set whole-Blitz duration.
4. Use institution synchronized/individual start mode.
5. Teacher activates Blitz.
6. Give each Student one normal attempt.
7. Show authoritative remaining time.
8. Explicit submit or timeout auto-finalization.
9. Give zero for unanswered timeout questions.
10. Reject late writes.
11. Permit one Student-specific Teacher-approved additional attempt with required reason.
12. Preserve/exclude original invalid attempt under exception.
13. Apply approved objective/partial-credit scoring.
14. Support manual review.
15. Determine official Blitz score.
16. Feed official score into Topic result.
17. Apply result-release rules.
18. Protect access/history.
### MVP Result Calculation Flow Scope

The MVP Result Calculation Flow includes:

1. Use one designated official Homework + one designated official Blitz.
2. Select highest valid Homework attempt.
3. Select valid official Blitz attempt.
4. Wait for required manual review.
5. Use common 0–100 scale.
6. Preserve full internal precision.
7. Calculate `D = |H - B|`.
8. Apply institution threshold `T`.
9. Average when `D <= T`.
10. Use Blitz when `D > T`.
11. Mark consistency without automatic cheating accusation.
12. Assign category from derived integer `category_score`.
13. Display scores with one decimal.
14. Store rule/calculation snapshots.
15. Separate calculation from visibility.
16. Support Student automatic/manual release.
17. Support Parent with-Student/manual/hidden modes.
18. Prevent Parent release before Student.
19. Preserve historical closed results.
### MVP Result Status Flow Scope

MVP result calculation statuses:

- Waiting for Homework
- Waiting for Blitz task
- Waiting for Teacher review
- Calculated
- Not completed
- Closed

Student and Parent visibility are separate state dimensions.

`Not completed` is used only after required work can no longer validly be completed. Waiting for review or hidden/unreleased results must not be treated as Not completed.
### MVP Reports and Progress Flow Scope

The MVP should include simple and practical progress visibility.

The included report flows are:

1. Super Admin views basic platform statistics.
2. Institution Admin views basic institution summaries.
3. Teacher views topic progress.
4. Teacher views group progress.
5. Teacher views individual student progress.
6. Student views personal progress.
7. Parent views connected child progress.
8. Reports show homework completion.
9. Reports show blitz completion.
10. Reports show homework score.
11. Reports show blitz score.
12. Reports show final result.
13. Reports show understanding category.
14. Reports show students waiting for teacher review.
15. Reports show students with incomplete tasks.
16. Reports show students who need revision.
17. Reports show students who need teacher support.
18. Reports show large homework/blitz score differences.
19. Reports use basic filters.
20. Reports protect data according to role and scope.

The MVP should not include predictive analytics, advanced interactive charts, downloadable reports, custom report builders, automated weekly summaries, or comparisons across many institutions.

### MVP Access and Permission Flow Scope

The MVP Access and Permission Flow should include:

1. Login and logout.
2. Active and inactive user status.
3. Active and inactive institution status.
4. Role-based access control.
5. Institution-based data separation.
6. Group-based access.
7. Teacher-assigned group access.
8. Student-assigned task access.
9. Parent-child relationship access.
10. Separate view and edit permissions.
11. Protected user-management actions.
12. Protected topic and material actions.
13. Protected homework actions.
14. Protected blitz actions.
15. Protected submission access.
16. Protected file access.
17. Protected score and result access.
18. Protected report access.
19. Clear permission-denial messages.
20. Consistent permissions across desktop and mobile.

The MVP should not include custom roles, two-factor authentication, enterprise identity systems, complex session controls, device restrictions, IP rules, or advanced audit analysis.

### MVP Device Flow Scope

The approved MVP device-access model is:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

The MVP should not try to make every feature available on every device.

The desktop and mobile flows should focus on the actions most appropriate for each role.

For example:

- Teachers create complex content on desktop.
- Teachers activate blitz tasks and view quick progress on mobile.
- Students complete detailed written or file-based work on desktop.
- Students complete simple tasks and blitz activities on mobile.
- Parents monitor child progress on mobile.
- Admins manage users, settings, groups, and reports on desktop.

Tablet-specific interfaces, offline applications, desktop notifications, biometric login, and advanced responsive layouts can be improved later.

### Main Flows Excluded from the MVP

To keep the first version realistic and buildable, the MVP should not include the following flows:

- AI-generated content flows
- AI answer-checking flows
- AI recommendation flows
- Audio lesson flows
- Video lesson flows
- Speaking-assignment flows
- Listening-assignment flows
- Video-response flows
- Coding-assignment flows
- Group-project flows
- Peer-review flows
- Plagiarism-checking flows
- Advanced question-bank flows
- Advanced randomized-test flows
- Advanced anti-cheating flows
- Live classroom competition flows
- Advanced analytics flows
- Predictive student-risk flows
- Teacher-performance analysis flows
- Communication and chat flows
- Teacher-parent messaging flows
- Announcement flows
- Notification and reminder flows
- Payment and subscription flows
- Billing and invoice flows
- External integration flows
- Advanced institution branding flows
- Custom role creation flows
- Advanced audit and security flows
- Offline synchronization flows
- Gamification flows
- Certificate flows
- Complex course-builder flows
- Advanced content-library flows

These exclusions do not mean the features are unnecessary. They mean they are not required to prove the core idea of the MVP.

### Future AI Flow Improvements

AI may be added after the core platform works reliably.

Future AI flows may include:

1. Teacher uploads learning materials.
2. AI analyzes the materials.
3. AI suggests topic summaries.
4. AI generates homework questions.
5. AI generates blitz questions.
6. Teacher reviews and edits generated content.
7. Teacher approves the final questions.
8. AI suggests accepted answers or scoring guidance.
9. AI assists with written-answer analysis.
10. AI suggests feedback for the teacher.
11. AI identifies common student mistakes.
12. AI suggests revision tasks.
13. AI recommends which students may need support.

AI should assist the teacher, not replace the teacher.

The teacher should remain responsible for:

- Approving generated questions
- Editing learning content
- Reviewing scores
- Making final educational decisions
- Deciding how students should be supported

### Future Audio and Video Flow Improvements

Future versions may support audio and video learning.

Possible future flows include:

1. Teacher uploads an audio lesson.
2. Student listens to the lesson inside the platform.
3. Teacher uploads a video lesson.
4. Student watches the video inside the platform.
5. Teacher creates a listening task.
6. Student listens and answers questions.
7. Teacher creates a speaking task.
8. Student records a voice answer.
9. Teacher creates a video-response task.
10. Student records or uploads a video.
11. Teacher reviews audio or video submissions.
12. System stores and reports the results.

These flows may be especially useful for language learning, pronunciation practice, presentations, and visual subjects.

### Future Assignment Flow Improvements

Future assignment improvements may include:

- Speaking tasks
- Listening tasks
- Video responses
- Coding tasks
- Project-based assignments
- Group assignments
- Peer review
- Rubric-based grading
- Difficulty levels
- Question banks
- Random question selection
- Reusable assignment templates
- Plagiarism checking
- Advanced file rules

For example, a future question-bank flow may work like this:

1. Teacher creates reusable questions.
2. Questions are organized by subject, topic, type, and difficulty.
3. Teacher selects questions from the bank.
4. The system creates an assignment or blitz task.
5. The teacher reviews and publishes it.
6. Questions may be reused for other groups or future lessons.

These flows should be added only after the simple assignment builder works well.

### Future Blitz Task Flow Improvements

Future blitz improvements may include:

- AI-generated blitz questions
- Random question selection
- Live classroom mode
- Real-time answer tracking
- QR-code or access-code entry
- Advanced anti-cheating tools
- Device monitoring
- Automatic difficulty adjustment
- Live result dashboards
- Advanced classroom reports

A future live classroom flow may work like this:

1. Teacher prepares the blitz task.
2. System generates a classroom access code.
3. Students enter the code.
4. Teacher starts the live session.
5. Students answer questions.
6. Teacher views real-time participation.
7. System closes the session automatically.
8. Results appear immediately.
9. Teacher reviews students who need attention.

These features should not make the blitz process unnecessarily complicated.

### Future Reports and Analytics Flow Improvements

Future reports may provide deeper learning analysis.

Possible future report flows include:

1. View long-term student progress.
2. Compare performance across topics.
3. Compare groups or classes.
4. Identify difficult topics.
5. Identify common mistakes.
6. View homework/blitz consistency trends.
7. Identify students at risk of falling behind.
8. Generate AI-based recommendations.
9. Export reports to Excel or PDF.
10. Generate weekly progress summaries.
11. Generate parent progress reports.
12. View institution performance dashboards.
13. View teacher activity reports.
14. Compare subject-level results.

These flows should be designed to support educational decisions, not only display more numbers.

### Future Communication Flow Improvements

Communication tools may be added later.

Possible communication flows include:

- Teacher comments on assignments
- Teacher feedback threads
- Teacher-student messaging
- Teacher-parent messaging
- Group announcements
- Institution announcements
- Support messages
- Task-related discussion
- Revision guidance

A future teacher-parent flow may work like this:

1. Teacher identifies a student who needs support.
2. Teacher opens the student’s progress page.
3. Teacher writes a message to the connected parent.
4. Parent receives the message.
5. Parent reads the teacher’s explanation.
6. Parent may reply if communication is allowed.
7. The conversation remains connected to the student and institution.

Communication features should remain controlled and should not turn the platform into an unrelated general chat application.

### Future Notification and Reminder Flow Improvements

Future versions may include notifications and reminders.

Possible notification flows include:

- New topic notification
- New learning material notification
- Homework deadline reminder
- Active blitz notification
- Result-ready notification
- Teacher-review-completed notification
- Parent progress notification
- Weekly child progress summary
- Institution activity alert
- Account or institution status alert

Notifications may first appear inside the application.

Later, they may be connected to:

- Mobile push notifications
- Email
- SMS
- Telegram
- Other approved services

### Future Monetization Flow Improvements

The MVP will be free and should not include monetization flows.

Future monetization flows may include:

1. Institution selects a plan.
2. System shows included features and limits.
3. Institution enters payment information.
4. Payment is processed.
5. Subscription becomes active.
6. Institution receives access to plan features.
7. System tracks renewal date.
8. Institution receives billing notifications.
9. Institution views invoices.
10. Super Admin manages plans and subscriptions.

Future monetization options may include:

- Institution subscriptions
- Free and paid plans
- Paid AI features
- Paid advanced analytics
- Paid storage
- Premium support
- Custom institutional licenses

Monetization should be added only after the product has demonstrated real educational value.

### Future External Integration Flow Improvements

Future versions may connect **TestLabUz** with external systems.

Possible integration flows include:

- Google Classroom
- Moodle
- Telegram
- Email
- SMS
- Google Drive
- Microsoft OneDrive
- Calendar services
- Payment systems
- Student information systems

For example, a future Google Classroom integration flow may work like this:

1. Institution connects its Google Classroom account.
2. Admin grants required permission.
3. Groups or classes are imported.
4. Teachers and students are matched.
5. Topics or assignments may be synchronized.
6. Results may be transferred according to approved rules.

External integrations should be added only when institutions clearly need them.

### Future Institution Customization Flow Improvements

Future institutions may need more customization.

Possible customization flows include:

- Upload institution logo
- Select institution colors
- Configure custom grading rules
- Configure custom understanding categories
- Configure custom task rules
- Configure advanced Parent visibility workflows beyond the approved MVP modes
- Configure advanced Student result-release workflows beyond the approved MVP modes
- Configure report formats
- Configure group structures
- Configure role permissions

These flows should remain controlled so institutions cannot break the core learning-check logic.

### Future User Role Flow Improvements

The MVP includes five roles:

1. Platform Owner / Super Admin
2. Institution Admin
3. Teacher
4. Student
5. Parent

Future roles may include:

- Institution Owner / Director
- Department Manager
- Group or Class Curator
- Assistant Teacher
- Content Moderator
- Platform Support Agent
- Finance or Billing Manager
- Report Viewer
- Guest or Observer

New role flows should be added only after real institutions confirm that the existing five roles are not enough.

### Future Security Flow Improvements

Future security improvements may include:

- Two-factor authentication
- Advanced audit logs
- Session management
- Device management
- Suspicious activity detection
- IP restrictions
- Advanced file scanning
- Custom permission groups
- Custom roles
- Enterprise security settings

A future session-management flow may allow users to:

1. View active login sessions.
2. See device and login information.
3. End one session.
4. End all other sessions.
5. Receive alerts about unusual access.

These security flows should be added as the platform grows and more institutions begin using it.

### Future Offline and Performance Flow Improvements

Future versions may support users with weak or unstable internet connections.

Possible offline and performance flows include:

- Download materials for offline viewing
- Save homework drafts offline
- Auto-save student answers
- Continue after connection loss
- Synchronize answers when internet returns
- Resume interrupted file uploads
- Optimize large document loading
- Improve mobile performance
- Improve desktop performance
- Support larger institutions

A future offline homework flow may work like this:

1. Student downloads an assignment while online.
2. Student writes answers offline.
3. The application stores the answers securely on the device.
4. Internet connection returns.
5. The application synchronizes the answers.
6. Student reviews and submits the final assignment.

Offline blitz tasks may require stricter rules and should be considered separately because blitz tasks are time-sensitive and classroom-based.

### Future Student Motivation Flow Improvements

Future versions may add motivation features.

Possible flows include:

- Earn badges
- Complete learning milestones
- Maintain study streaks
- Receive certificates
- Set personal learning goals
- View a progress timeline
- Receive revision suggestions
- Celebrate completed topics

Motivation features should support learning without replacing meaningful educational progress with unnecessary competition.

### Future Content Organization Flow Improvements

As institutions create more content, teachers may need better organization tools.

Possible future content flows include:

- Topic templates
- Assignment templates
- Reusable lesson structures
- Material libraries
- Question banks
- Subject-based organization
- Topic version history
- Material version history
- Content search
- Archive management
- Copy content between groups
- Reuse content in a new academic period

These flows should be added after institutions begin creating enough content to need them.

### Future Flow Selection Rules

Not every future flow must be built.

Future improvements should be selected according to:

- Real teacher feedback
- Real student needs
- Parent usability
- Institution management needs
- Business value
- Educational value
- Technical complexity
- Security requirements
- Development cost
- Maintenance cost
- Platform performance
- Frequency of requested use
- Compatibility with the core product idea

A future flow should be prioritized when:

- Many real users request it.
- It solves a clear problem.
- It improves the core learning-check process.
- It can be built without damaging existing workflows.
- Its educational or business value is clear.
- The platform is technically ready for it.

A future flow should be delayed when:

- Its purpose is unclear.
- Only a small number of users may need it.
- It creates major complexity.
- It depends on unstable external services.
- It weakens privacy or security.
- It distracts from the core learning process.

### Transition from MVP to Future Versions

The platform should move from MVP to future versions only after the approved core rules are tested end to end.

Recommended verification before expansion:

1. Test multi-institution separation.
2. Test all five role boundaries.
3. Test official Homework/Blitz pair designation and lock behavior.
4. Test 3-attempt Homework and highest-score selection.
5. Test one-attempt Blitz.
6. Test Student-specific additional Blitz exception.
7. Test synchronized timing.
8. Test individual timing.
9. Test timeout auto-finalization and unanswered-zero behavior.
10. Test partial-credit rules.
11. Test manual review and recalculation.
12. Test full-precision threshold/category behavior and one-decimal display.
13. Test Student automatic/manual release.
14. Test all three Parent visibility modes and Student-first hierarchy.
15. Test upload limits.
16. Test institution timezone and UTC deadline enforcement.
17. Test desktop/mobile permission consistency.
18. Collect real user feedback.
19. Prioritize one future improvement group at a time.

Future development should be driven by real usage rather than assumptions.
### MVP Flow Success Criteria

The MVP flows are successful when:

1. Super Admin manages institutions correctly.
2. Institution Admin manages users/groups and approved institution settings.
3. Teachers work only inside assigned scope.
4. Topics/materials can be created and accessed securely.
5. Learning materials respect the 25 MB platform maximum.
6. Official Homework/Blitz pair designation works and locks at the correct time.
7. Students receive exactly 3 normal Homework attempts.
8. Highest valid completed Homework score becomes official.
9. Students normally receive one Blitz attempt.
10. Teacher can grant exactly one Student-specific additional Blitz attempt with a reason.
11. Both synchronized and individual timing modes work.
12. Timeout auto-finalizes saved answers and unanswered items receive zero.
13. Student files respect the 15 MB platform maximum.
14. Approved partial-credit rules calculate correctly.
15. Manual review completes before affected official scores/results.
16. Threshold and final formula use unrounded values.
17. Category assignment uses derived integer `category_score`.
18. UI displays scores with one decimal.
19. Student release modes work.
20. Parent visibility modes work and never precede Student release.
21. UTC/institution-timezone behavior is correct.
22. Historical results remain stable.
23. Every institution's data stays isolated.
24. Desktop/mobile flows enforce the same permissions.
25. Non-technical users can complete the end-to-end workflow.
### MVP Flow Scope Summary

In the MVP version, **TestLabUz** should include the following main flows:

1. Platform Owner / Super Admin flow
2. Institution Admin flow
3. Teacher flow
4. Student flow
5. Parent flow
6. Institution setup flow
7. User-management flow
8. Group-management flow
9. Teacher-group assignment flow
10. Student-group assignment flow
11. Parent-student connection flow
12. Topic creation flow
13. Learning material upload flow
14. Homework creation flow
15. Homework completion flow
16. Assignment submission flow
17. Automatic checking flow
18. Manual teacher checking flow
19. Blitz task creation flow
20. Blitz activation flow
21. Blitz participation flow
22. Blitz monitoring flow
23. Homework and blitz score-comparison flow
24. Final result calculation flow
25. Understanding category flow
26. Basic reports and progress flow
27. Access and permission flow
28. Institution data-separation flow
29. Desktop role-access flow
30. Mobile role-access flow

The MVP should exclude flows that are not necessary for proving the core learning-check idea.

### Future Flow Improvements Summary

Future versions may add or improve:

1. AI-assisted learning flows
2. Audio and video flows
3. Advanced assignment flows
4. Advanced blitz flows
5. Advanced reports and analytics
6. Communication flows
7. Notification and reminder flows
8. Monetization flows
9. External integration flows
10. Advanced institution customization
11. Additional user-role flows
12. Advanced security flows
13. Offline and synchronization flows
14. Student motivation flows
15. Advanced content-organization flows

The future scope should remain flexible. Features and flows should be selected based on real user feedback, institution needs, technical complexity, educational value, and business value.

The main rule is simple:

**Future flows should improve the core product, not distract from it.**

The MVP should first prove that **TestLabUz** can help teachers measure real student understanding by comparing homework results with short in-class blitz results.

After that, future flows can be added gradually to make the platform more intelligent, flexible, scalable, secure, and valuable for educational institutions.
# Post-Audit Flow Clarifications

The following flow rules are mandatory in every affected role flow:

- **Institution setup:** creation initializes `Asia/Tashkent` and platform-max upload limits; threshold, category ranges, Blitz timer mode, Student release mode, and Parent visibility mode remain unconfigured until Institution Admin setup. A missing setting blocks only its dependent operation.
- **First login:** every administrator-created Institution Admin/Teacher/Student/Parent logs in with the initial password, is routed to Change Password, supplies the current initial password plus the new password/confirmation, and cannot use normal endpoints until the change succeeds.
- **Official Topic assessment:** only whole-group Homework/Blitz may become official. The first official task activation snapshots the current group cohort and the second official task reuses it; later Group membership changes do not alter that Topic cohort.
- **Multiple-choice:** Student sees `max_selections`; choosing above that limit is blocked by Flutter and rejected by Laravel. Score = correct selections / total correct options; empty answer = zero.
- **Short Written automatic checking:** both accepted and Student text follow the same deterministic normalization pipeline; no fuzzy or AI interpretation occurs.
- **Activation:** server recalculates total points and blocks activation when total possible points is zero.
- **Task closure:** Teacher close immediately blocks writes and auto-finalizes all existing in-progress attempts from saved answers with `task_closed_auto_finalize`; unanswered components receive zero; never-started Students receive no fake Attempt.
- **Result closure:** Teacher may close only a calculated terminal result or a definitive Not completed result. Waiting states, in-progress official attempts, pending Blitz replacement attempts, or incomplete manual review block closure. Release may occur before or after closure according to policy.
- **Category assignment:** final calculation remains unrounded; the category resolver uses integer `category_score` with `.0`–`.5` down and `>.5` up.
- **Homework highest-score tie:** earliest tied attempt becomes the official attempt reference.
