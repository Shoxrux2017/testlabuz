# TestLabUz — Features

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

## 1. Features Overview

**TestLabUz** is an educational platform designed to help educational institutions monitor how well students understand and master specific topics.

The main feature of the system is the topic-based learning-check process. A teacher creates a topic, uploads learning materials, gives homework assignments, and then checks the student’s real understanding through a short in-class blitz task. After that, the system compares the homework result with the blitz result and shows the student’s final understanding level through clear assessment categories.

The MVP version of **TestLabUz** should focus on the core workflow:

1. The teacher creates a topic.
2. The teacher uploads learning materials.
3. The teacher creates homework assignments.
4. The student studies the materials independently.
5. The student completes the homework.
6. The teacher gives a short blitz task during class.
7. The student completes the blitz task.
8. The system compares the homework and blitz results.
9. The system calculates the final result.
10. The teacher, student, and parent can view the result according to their access level.

The system will support multiple educational institutions from the beginning. Each institution will have its own users, groups, topics, assignments, blitz tasks, results, settings, and reports. Data from one institution must remain separate from data belonging to another institution.

The MVP version will include the following main roles:

1. **Platform Owner / Super Admin**
2. **Institution Admin**
3. **Teacher**
4. **Student**
5. **Parent**

Each role will have its own features and access level. The Platform Owner / Super Admin manages the whole platform. The Institution Admin manages one institution. Teachers manage topics, materials, assignments, blitz tasks, and student results. Students study materials, complete tasks, and view their own results. Parents monitor their child’s learning progress.

The system will support learning materials in the following formats in the MVP version:

- PDF
- DOCX
- PPT
- PPTX

The system will also support different assignment types, including single-choice tests, multiple-choice tests, true / false questions, short written answers, open written answers, file-based assignments, matching tasks, ordering tasks, and fill-in-the-blank tasks.

Blitz tasks will be created manually by teachers in the MVP version. These tasks should be short, focused, and time-limited. Their purpose is to verify whether the student truly understood the topic and completed the homework independently.

The MVP uses fixed attempt rules for the core learning-check process. Each Homework gives a Student exactly **3 normal attempts**, and the official Homework score is the **highest valid completed score** from those attempts. Each Blitz gives a Student exactly **1 normal attempt**. When a valid technical or other approved problem prevents proper Blitz completion, an authorized Teacher may grant **one additional Blitz attempt to that specific Student**, with a required reason. The interrupted or invalid attempt remains in history and is excluded from official scoring according to the approved exception.

Student results should not be shown only as numeric scores. The system should show clear understanding categories, such as:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The platform should support different device access based on user role. Platform Owner / Super Admin and Institution Admin should use the desktop version. Teachers and students should have both desktop and mobile access. Parents should use the mobile version.

The MVP should stay simple and practical. It should not include advanced features too early. AI features, audio and video assignments, monetization, advanced analytics, communication tools, external integrations, and complex customization should be added later after the core workflow is tested and improved.

The purpose of this feature document is to clearly define what **TestLabUz** must do in the MVP version and what should be left for future versions.

## 2. Platform Owner / Super Admin Features

The **Platform Owner / Super Admin** is the highest-level user in **TestLabUz**. This role manages the whole platform and controls educational institutions that use the system.

The Super Admin does not manage only one school, university, or learning center. Instead, this role manages the full platform where many institutions can be registered and used separately.

In the MVP version, Super Admin features should focus on basic platform management, institution control, platform monitoring, and support.

The Super Admin should be able to manage educational institutions inside the platform. This includes creating a new institution account, viewing institution information, editing basic institution details, and checking whether an institution is active or inactive.

The Super Admin should be able to view a list of all institutions using **TestLabUz**. This list should show important basic information, such as institution name, institution type, status, number of users, and general activity information.

The Super Admin should be able to activate or deactivate an institution. If an institution is deactivated, users from that institution should not be able to continue using the platform normally until the institution is activated again.

The Super Admin should be able to view basic platform statistics. These statistics may include the total number of institutions, active institutions, inactive institutions, total users, active users, and general platform usage information.

The Super Admin should be able to manage or assist Institution Admins when needed. For example, if an Institution Admin loses access, has a configuration problem, or needs platform-level support, the Super Admin should be able to help.

The Super Admin should be able to view basic support and issue reports from institutions. This helps the platform owner understand which institutions may need help or which parts of the system may require improvement.

The Super Admin should be able to manage basic global platform settings. These settings should affect the whole platform, not only one institution. In the MVP version, these settings should stay simple and should not include advanced customization.

The Super Admin should be able to access a platform dashboard. This dashboard should give a quick overview of platform health, institution status, user activity, and important items that may need attention.

The Super Admin should not normally interfere with daily educational work inside an institution. For example, the Super Admin should not usually change student answers, teacher-created assignments, blitz tasks, or class results unless there is a support, security, or system management reason.

The Super Admin should use the desktop version of the platform. This role needs management tools, tables, filters, dashboards, and institution-level controls, so the desktop interface is the most suitable option.

In the MVP version, the Platform Owner / Super Admin should have the following main features:

1. View platform dashboard
2. View all institutions
3. Create new institutions
4. Edit basic institution information
5. Activate institutions
6. Deactivate institutions
7. View institution status
8. View basic institution usage information
9. View basic platform statistics
10. Manage or support Institution Admin access
11. View support or issue reports
12. Manage basic global platform settings

Advanced Super Admin features should be added later. These may include billing, subscriptions, license management, advanced platform analytics, detailed audit logs, storage limits, premium feature control, and platform support team management.

The main purpose of Super Admin features in the MVP is to keep the **TestLabUz** platform organized, make sure institutions are properly managed, and provide basic control over the multi-institution system.

## 3. Institution Admin Features

The **Institution Admin** is the main management user inside one educational institution in **TestLabUz**.

This role does not manage the whole platform. Instead, the Institution Admin manages only their own school, college, lyceum, university, institute, learning center, or other educational organization.

The main purpose of Institution Admin features is to help each institution organize its users, groups, settings, and learning structure correctly.

The Institution Admin should be able to manage the institution’s basic profile. This may include the institution name, type, status, contact information, and other basic information needed to identify the institution inside the system.

The Institution Admin should be able to manage users inside their own institution. This includes creating, viewing, editing, activating, and deactivating teacher, student, and parent accounts.

The Institution Admin should be able to connect parents to students. For example, one parent may be connected to one child, or one parent may be connected to multiple children. A student may also have one or more parents connected to them.

The Institution Admin should be able to create and manage classes or groups. Groups are important because teachers, students, topics, assignments, and results will often be organized by group.

The Institution Admin should be able to assign students to groups. This allows students to receive the correct topics, materials, homework assignments, and blitz tasks.

The Institution Admin should be able to assign teachers to groups. This defines which teachers can create topics, upload materials, assign homework, give blitz tasks, and review results for specific students.

The Institution Admin should be able to manage basic role and access rules inside the institution. For example, they should be able to decide which users are teachers, which users are students, and which users are parents.

The Institution Admin should be able to configure assessment category settings for the institution. These settings define how final results are converted into understanding categories such as “Understood well,” “Partially understood,” “Needs revision,” and “Needs teacher support.”

The Institution Admin should **not** configure arbitrary Homework or Blitz attempt counts in the MVP. The approved attempt rules are fixed: Homework has 3 normal attempts; Blitz has 1 normal attempt, with at most one additional Student-specific Blitz attempt granted by an authorized Teacher for a valid reason.

The Institution Admin should instead configure the institution-level learning settings that legitimately vary between institutions:

- Acceptable Homework–Blitz score-difference threshold
- Understanding-category score ranges
- Blitz timer-start mode: **synchronized** or **individual**
- Student result-release mode: **automatic** or **manual Teacher release**
- Parent result-visibility mode: **with Student**, **manual Teacher release**, or **hidden**
- Institution timezone using an IANA timezone identifier
- Institution upload limits that may be lower than, but never exceed, the platform maximums

The Institution Admin should be able to configure the institution timezone using an IANA timezone identifier, such as `Asia/Tashkent`. Teachers enter educational deadlines and schedules in institution local time, while authoritative timestamps are stored and compared as UTC instants on the server. Device time must not change deadlines or Blitz timing.

The Institution Admin should be able to view basic institution progress information. This may include group activity, student completion status, topic progress, and general performance information.

The Institution Admin should be able to view basic reports for their own institution. These reports should help admins understand whether teachers, students, and groups are actively using the system.

The Institution Admin should be able to see which groups or students may need attention. For example, they may need to know if many students did not complete tasks, if many students need teacher support, or if a group has low activity.

The Institution Admin should not normally create daily learning content instead of teachers. For example, they should not usually create homework assignments, create blitz tasks, or check student answers unless the institution specifically allows that in future versions.

The Institution Admin should not complete assignments for students, answer blitz tasks, change student submissions, or directly manipulate learning results.

The Institution Admin can only access data that belongs to their own institution. They must not be able to view or manage users, groups, topics, assignments, results, or settings from another institution.

The Institution Admin should use the desktop version of the platform. Admin work requires tables, filters, user management, group management, settings, and reports, so the desktop interface is the most suitable option.

In the MVP version, the Institution Admin should have the following main features:

1. View institution dashboard
2. View and edit basic institution profile
3. Create teacher accounts
4. Edit teacher accounts
5. Activate or deactivate teacher accounts
6. Create student accounts
7. Edit student accounts
8. Activate or deactivate student accounts
9. Create parent accounts
10. Edit parent accounts
11. Activate or deactivate parent accounts
12. Connect parents to students
13. Create classes or groups
14. Edit classes or groups
15. Assign students to groups
16. Assign teachers to groups
17. Manage basic institution role access
18. Configure assessment category settings
19. Configure acceptable Homework–Blitz score-difference threshold
20. Configure Blitz timer-start mode
21. Configure Student result-release mode
22. Configure Parent result-visibility mode
23. Configure institution timezone
24. Configure lower institution upload limits
25. View basic group progress
26. View basic student progress overview
27. View basic institution reports
28. See groups or students that may need attention

Advanced Institution Admin features should be added later. These may include advanced analytics, custom workflows, advanced grading rules, institution branding, department management, advanced permission management, communication tools, integrations, and detailed audit reports.

The main purpose of Institution Admin features in the MVP is to keep one institution organized inside **TestLabUz** and make sure teachers, students, and parents have the correct access to the learning process.

## 4. Teacher Features

The **Teacher** is the main educational user in **TestLabUz**.

Teachers are responsible for creating the learning process around topics, materials, homework assignments, blitz tasks, and student results. The main purpose of teacher features is to help teachers check not only whether students completed assignments, but also whether they truly understood the topic.

A teacher works inside one educational institution and can only manage the groups, students, topics, assignments, blitz tasks, and results assigned to them. Teachers must not access data from other institutions or unrelated groups.

The teacher should be able to view their own dashboard. This dashboard should show important teaching information, such as assigned groups, active topics, pending assignments, upcoming blitz tasks, student completion status, and students who may need attention.

The teacher should be able to create and manage topics. Each topic represents one learning subject or lesson area that students need to study and master.

When creating a topic, the teacher should be able to add basic information such as topic title, description, subject, group, lesson date, and related instructions.

The teacher should be able to upload learning materials for each topic. In the MVP version, supported material formats are:

- PDF
- DOCX
- PPT
- PPTX

These materials help students study independently after the lesson. Teachers should be able to add, update, remove, open, or download materials connected to their own topics.

The teacher should be able to create homework assignments connected to a topic. Homework assignments are completed by students outside the classroom after studying the uploaded materials.

The MVP version should support the following assignment types for teachers:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

The teacher should be able to create questions, answer options, correct answers, instructions, points, and task rules depending on the assignment type.

Homework attempts are fixed in the MVP. Every assigned Student receives exactly **3 normal Homework attempts**. The Teacher does not configure a different attempt count. The system stores each attempt separately and uses the **highest valid completed score** as the official Homework score after any required manual checking is complete.

The teacher should be able to manually create blitz tasks connected to the same topic as the homework assignment. Blitz tasks are short in-class tasks used during the first 5–10 minutes of the next lesson.

The teacher should be able to choose Blitz questions, define points and scoring rules, set the **whole-Blitz duration**, and decide which authorized group or Students should receive the Blitz. The Teacher does not define arbitrary Blitz attempt counts.

The teacher should be able to start or activate a Blitz task during class. Students should only be able to answer the Blitz after Teacher activation and according to the institution's configured timer-start mode.

- **Synchronized start:** Teacher activation starts the timer for all assigned Students.
- **Individual start:** Teacher activation makes the Blitz available, and each Student's timer starts when that Student begins the attempt.

The server is authoritative for all Blitz timing.

The teacher should be able to monitor Blitz progress during class. For example, the Teacher should see which Students have access, started, are in progress, were auto-finalized at timeout, submitted, are waiting for manual review, did not complete the task, or have an approved technical-attempt exception.

The teacher should be able to review student submissions. Some assignment types can be checked automatically by the system, such as tests, true / false questions, matching tasks, ordering tasks, and fill-in-the-blank tasks.

Other assignment types may require manual checking by the teacher. These include open written answers and file-based assignments. The teacher should be able to review the submitted answer, assign a score, and add feedback if needed.

After students complete homework and blitz tasks, the teacher should be able to view both results together. The system should show the homework score, blitz score, final calculated result, and understanding category.

The system should help the teacher compare the homework score and blitz score. If the two scores are close to each other, the system calculates the average score. If there is a big difference, the blitz score is used as the student’s real result.

The teacher should be able to view understanding categories for students, such as:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The teacher should be able to filter and review students by result category. This helps the teacher quickly understand which students are ready to continue, which students need more practice, and which students need direct support.

The teacher should be able to view progress by topic, group, and individual student. This helps the teacher understand how well a specific group or student is learning over time.

The teacher should be able to see Students who did not complete Homework, did not complete Blitz tasks, used all three Homework attempts, used the normal Blitz attempt, received an approved additional Blitz attempt, or received low understanding categories.

The teacher should be able to use both desktop and mobile versions of the platform. The desktop version should be used for larger tasks such as creating topics, uploading files, creating assignments, checking written answers, and reviewing detailed results.

The mobile version should support quick teacher actions, such as viewing groups, checking task status, starting blitz tasks, monitoring class progress, and reviewing basic student results.

Teachers should not manage institution-wide settings unless the institution gives them permission in a future version. Teachers should not create or manage institution accounts, access unrelated groups, change another teacher’s content, view another institution’s data, or change student submissions after system rules no longer allow it.

In the MVP version, the Teacher should have the following main features:

1. View teacher dashboard
2. View assigned groups
3. View assigned students
4. Create topics
5. Edit own topics
6. Upload learning materials
7. Manage own learning materials
8. Create homework assignments
9. Create supported assignment types
10. Apply fixed 3-attempt Homework rule
11. Create manual Blitz tasks
12. Configure whole-Blitz duration
13. Start or activate Blitz tasks during class
14. Monitor Blitz task progress
15. Grant one Student-specific additional Blitz attempt for a valid reason
16. Review Student submissions
17. Manually check open written answers
18. Manually check file-based assignments
19. View official Homework scores
20. View official Blitz scores
21. View final calculated results
22. View understanding categories
23. Filter Students by result category
24. View Topic progress
25. View group progress
26. View individual Student progress
27. Release Student results when institution policy requires it
28. Release Parent results when institution policy requires it
29. Identify Students who need revision or Teacher support

Advanced teacher features should be added later. These may include AI-generated questions, AI answer checking, audio and video assignments, advanced analytics, communication with students or parents, reusable question banks, lesson planning tools, and integration with external learning platforms.

The main purpose of Teacher features in the MVP is to support the full learning-check process: create a topic, provide materials, assign homework, give a blitz task, compare results, and understand each student’s real learning level.

## 5. Student Features

The **Student** is the main learning user in **TestLabUz**.

Students use the system to study learning materials, complete homework assignments, answer blitz tasks during class, and view their own learning results.

A student belongs to one educational institution and may be connected to one or more classes or groups inside that institution. Students should only see the topics, materials, assignments, blitz tasks, and results assigned to them.

The student should be able to view their own dashboard. This dashboard should show assigned topics, active homework assignments, upcoming or active blitz tasks, completion status, scores, and learning progress.

The student should be able to view assigned topics. Each topic should include basic information such as topic title, description, subject, teacher, group, instructions, and related learning materials.

The student should be able to open and study learning materials uploaded by the teacher. In the MVP version, supported material formats are:

- PDF
- DOCX
- PPT
- PPTX

Students should be able to open or download these materials, depending on the platform design. The main purpose of this feature is to help students review the topic independently after the lesson.

The student should be able to view homework assignments connected to a topic. Each homework assignment should show instructions, question types, deadline if applicable, available attempts, score rules, and completion status.

The student should be able to complete homework assignments using the supported assignment types:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

For file-based assignments, the Student should be able to upload an answer file according to the allowed formats and task rules. The platform hard maximum is **15 MB per Student submission file**; an institution may configure a lower limit.

For Homework, the Student should clearly see that exactly **3 normal attempts** are available, together with the current attempt number and remaining attempts. Each submitted attempt remains separate, and the highest valid completed Homework score becomes official.

The Student should not be able to start a fourth normal Homework attempt, start a new attempt after the Homework deadline or closure, or modify a finalized/submitted attempt. If the authoritative Homework deadline arrives while an Attempt is still in progress, Laravel must automatically finalize the saved work, score unanswered components as zero, preserve manual-review answers for Teacher checking, and make any unused remaining Homework attempts unavailable.

The student should be able to answer blitz tasks during class. A blitz task is short, focused, and connected to the same topic as the homework assignment.

The student should only be able to access a blitz task when the teacher starts or activates it. If the blitz task is not active, the student should not be able to answer it.

The Student should clearly see the remaining time for the **whole Blitz task**. The MVP does not use per-question Blitz timers.

The Student should normally receive exactly **1 Blitz attempt**. When the authoritative timer reaches zero, the system must stop accepting changes and **automatically finalize the Student's saved answers**. Answers saved before the deadline are evaluated normally; unanswered questions receive zero points; answers that require Teacher judgment remain waiting for manual review. Writes received after the deadline are rejected.

If a valid technical or other approved problem prevented proper completion, the Teacher may grant that Student exactly **one additional Blitz attempt**. The Student cannot grant this exception to themselves.

The student should be able to see the completion status of homework assignments and blitz tasks. For example, the system may show whether a task is not started, in progress, submitted, checked, or not completed.

After Homework and Blitz are complete and all required checking is finished, the system may calculate the Student's Topic result. Calculation and visibility are separate. The Student sees the result only after it is released according to the institution's Student result-release mode: **automatic** after full calculation or **manual Teacher release**.

Student results may include:

- Homework score
- Blitz score
- Final calculated result
- Understanding category
- Completion status
- Teacher feedback if available

The student should be able to view their own understanding category, such as:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The student should be able to understand which topics they completed successfully and which topics need more revision.

The student should only access their own learning information. Students must not be able to view other students’ answers, scores, private progress, personal information, or parent information.

Students should not be able to create official topics, upload official learning materials, create homework assignments, create blitz tasks, check answers, change scores, manage users, or change institution settings.

Students should use both desktop and mobile versions of the platform.

The desktop version should be useful for studying larger materials, completing written assignments, uploading files, and working with tasks that need more screen space.

The mobile version should be useful for studying materials, answering simple assignments, participating in blitz tasks during class, and quickly checking personal progress.

In the MVP version, the Student should have the following main features:

1. View student dashboard
2. View assigned topics
3. Open topic details
4. View learning materials
5. Open or download PDF, DOCX, PPT, and PPTX materials
6. View homework assignments
7. Complete homework assignments
8. Answer supported assignment types
9. Upload files for file-based assignments
10. View the fixed 3 Homework attempts
11. View remaining Homework attempts
12. Submit Homework answers
13. Access Teacher-activated Blitz tasks
14. View whole-Blitz remaining time
15. Use the normal Blitz attempt
16. Use one additional Blitz attempt when validly granted by the Teacher
17. Have saved Blitz work auto-finalized at timeout
18. View task completion and review status
19. View released official Homework score
20. View released official Blitz score
21. View released final calculated result
22. View released understanding category
23. View Teacher feedback if available
24. View personal learning progress
25. Identify Topics that need revision

Advanced student features should be added later. These may include audio and video assignments, AI study recommendations, personal learning plans, reminders, communication with teachers, discussion features, gamification, badges, certificates, and integration with external learning platforms.

The main purpose of Student features in the MVP is to help students study assigned topics, complete homework, answer blitz tasks honestly during class, and understand their own learning progress.

## 6. Parent Features

The **Parent** is the monitoring user in **TestLabUz**.

Parents use the system to follow their child’s learning progress, view results, and understand how well the child is mastering each topic. Parents do not create learning content, complete assignments, manage users, or change educational data.

A parent belongs to one educational institution and is connected to one or more students inside that institution. A parent should only see information about their own child or children. Parents must not be able to access other students’ data, other parents’ data, teacher-private information, or institution settings.

The parent should be able to view a simple parent dashboard. This dashboard should show the child’s general learning progress, recent topics, completed homework assignments, blitz task results, understanding categories, and topics that may need more attention.

If a parent has more than one child connected to their account, they should be able to switch between children and view progress separately for each child.

The parent should be able to view the child’s assigned topics. Each topic should show basic information such as topic title, subject, teacher, group, completion status, and learning result.

The parent should be able to see whether the child has completed the homework assignment for a topic. This helps the parent understand whether the child is actively doing the required learning tasks.

The parent should be able to see blitz task results. Since blitz tasks are used to check the child’s real understanding during class, these results are important for showing whether the homework result is reliable.

The Parent should be able to view the child's Homework score, Blitz score, final calculated result, and understanding category only according to the institution's Parent result-visibility mode:

- **With Student** — Parent access begins automatically after the Student result is released.
- **Manual Teacher release** — Parent access begins only after Student release and a separate Teacher release.
- **Hidden** — the Parent does not receive the Topic result.

A Parent must never receive a result before the Student result has been released.

The parent should be able to view understanding categories such as:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

These categories help parents understand the child’s learning condition more clearly than a numeric score alone.

The parent should be able to identify topics where the child needs more revision or teacher support. This helps parents support the child at home and understand when additional attention may be needed.

The parent should be able to view task completion status. For example, the system may show whether homework or blitz tasks are completed, not completed, checked, or waiting for teacher review.

The parent may be able to view teacher feedback if the teacher provides feedback for a homework assignment, open written answer, file-based assignment, or final result.

The parent should not be able to complete homework assignments for the student. They should not be able to answer blitz tasks, upload assignment files, change student answers, change scores, or edit understanding categories.

The parent should not be able to create topics, upload learning materials, create homework assignments, create blitz tasks, manage users, configure attempts, or change institution settings.

In the MVP version, parents should use only the mobile version of the platform. The parent interface should be simple, clear, and focused on monitoring progress. Parents do not need complex desktop management tools in the first version.

In the MVP version, the Parent should have the following main features:

1. View parent dashboard
2. View connected child or children
3. Switch between children if more than one child is connected
4. View child’s assigned topics
5. View topic completion status
6. View homework completion status
7. View blitz task results
8. View homework score
9. View blitz score
10. View final calculated result
11. View understanding category
12. View teacher feedback if available
13. View topics that need revision
14. View topics that need teacher support
15. View general learning progress
16. Monitor whether the child is completing assigned tasks

Advanced parent features should be added later. These may include notifications, weekly progress summaries, teacher-parent messaging, recommendations for helping the child study, attendance information, announcements, reminders, and detailed reports.

The main purpose of Parent features in the MVP is to give parents a simple way to monitor their child’s learning progress and understand when the child may need more support.

## 7. Topic and Learning Material Features

Topics and learning materials are one of the core parts of **TestLabUz**.

A topic represents a specific lesson, subject unit, or learning theme that students need to study and understand. Learning materials are the files uploaded by the teacher to help students review and study that topic independently after the lesson.

The main purpose of topic and learning material features is to organize the learning process clearly. Each topic should connect the teacher’s explanation, uploaded materials, homework assignments, blitz tasks, student submissions, scores, and understanding results.

The teacher should be able to create a topic for a specific group or class. The topic should belong to one educational institution and should only be visible to users who have access to that institution and group.

When creating a topic, the teacher should be able to add basic information such as:

- Topic title
- Topic description
- Subject
- Group or class
- Teacher
- Lesson date if needed
- Instructions for students
- Topic status

The topic status can help control whether students can access the topic. In the MVP version, simple statuses may be enough, such as draft, active, closed, or archived.

A draft topic is not yet visible to students. An active topic is visible to assigned students. A closed topic may no longer accept new homework or blitz submissions. An archived topic is kept for history but is no longer actively used.

The teacher should be able to edit their own topics if the topic belongs to their assigned group. The teacher should also be able to close or archive a topic when the learning process for that topic is finished.

The teacher should be able to upload learning materials connected to a Topic. These materials should help Students repeat the lesson, study independently, and prepare for Homework and Blitz tasks. The platform hard maximum is **25 MB per learning-material file**; an institution may configure a lower limit.

In the MVP version, the system should support the following learning material formats:

- PDF
- DOCX
- PPT
- PPTX

Each learning-material file has a platform hard maximum of **25 MB**. An Institution Admin may configure a smaller institution limit, but may not exceed the platform maximum.

Learning materials may include lesson notes, theoretical explanations, examples, presentations, instructions, reading materials, or other document-based resources related to the topic.

Each uploaded material should be connected to one specific topic. This makes it clear which materials students need to study before completing the homework assignment and blitz task.

The teacher should be able to manage learning materials for their own topics. This includes uploading new materials, viewing uploaded materials, replacing or updating materials, removing old materials, and checking which materials are attached to each topic.

Students should be able to open or download learning materials assigned to them. The exact behavior may depend on the platform design, but the student should have a simple way to access the material and study it.

The student should only see topics and materials assigned to their own group or class. Students must not be able to access topics or materials from unrelated groups, other institutions, or other teachers unless they are assigned to them.

Parents may be able to view basic topic information and topic progress for their own child. However, in the MVP version, parent access should stay simple and focused on monitoring progress, not managing materials.

Institution Admins may be able to view topic and material information inside their own institution for management or support purposes. However, they should not normally replace the teacher’s daily learning role unless institution rules allow it in future versions.

Topics should be connected to Homework assignments and Blitz tasks. A Topic may contain multiple Homework assignments and multiple Blitz tasks, but exactly **one whole-group Homework and one whole-group Blitz** are designated as the official result-bearing pair for the MVP Topic result. Selected-Student tasks are practice-only. Only the designated whole-group pair is used in the Homework–Blitz comparison and final understanding calculation.

For example, one Topic may include:

1. Learning materials
2. One or more Homework assignments
3. One or more Blitz tasks
4. One designated official Homework
5. One designated official Blitz
6. Official Homework score
7. Official Blitz score
8. Final Topic result
9. Understanding category

The designated official Homework and official Blitz must belong to the same Topic, both must use whole-group assignment, and selected-Student tasks are practice-only. When the first official task becomes active, the current eligible Topic-group Students are snapshotted as the official cohort and reused for both tasks. Once Student attempt activity begins, the pair and cohort must not be replaced.

The system should make it easy for teachers and students to understand this connection. Students should clearly see which materials, homework assignments, and blitz tasks belong to the same topic.

The system should protect uploaded materials. Users should only access files that belong to their institution, role, group, and permission scope.

The system should also keep the MVP simple. Advanced material features such as video lessons, audio lessons, interactive content, external links, AI-generated study materials, material version history, comments, and collaborative editing should be added later.

In the MVP version, Topic and Learning Material features should include:

1. Create topics
2. Edit own topics
3. Assign topics to groups or classes
4. Add topic title
5. Add topic description
6. Add subject information
7. Add student instructions
8. Manage topic status
9. Upload PDF materials
10. Upload DOCX materials
11. Upload PPT / PPTX materials
12. View uploaded materials
13. Replace or update uploaded materials
14. Remove uploaded materials
15. Open or download materials
16. Show materials to assigned students
17. Connect topics with homework assignments
18. Connect topics with blitz tasks
19. Show topic progress
20. Protect topic and material access by institution, role, group, and user permissions

Advanced topic and material features should be added later. These may include audio materials, video materials, external links, AI-generated summaries, AI-generated study resources, material version history, topic templates, reusable lesson structures, comments, and integration with external learning platforms.

The main purpose of Topic and Learning Material features in the MVP is to help teachers organize each learning topic clearly and give students the correct resources they need before completing homework and blitz tasks.

## 8. Assignment Features

Assignments are one of the main learning-check features in **TestLabUz**.

Assignments are tasks that teachers create to check how well students understand a specific topic. They are usually completed by students after studying the learning materials uploaded by the teacher.

The main purpose of assignment features is to help teachers give structured tasks, collect student answers, check results, and prepare for the next step of the learning process: the blitz task.

Each assignment should be connected to a specific topic. This is important because the system needs to understand which topic the assignment belongs to and later compare the homework result with the blitz task result for the same topic.

A teacher should be able to create homework assignments for their own assigned groups or students. The assignment should belong to the correct institution, group, topic, teacher, and students.

When creating an assignment, the teacher should be able to add basic information such as:

- Assignment title
- Assignment description
- Topic
- Group or class
- Instructions for students
- Assignment type
- Questions
- Answer options if needed
- Correct answers if needed
- Points or score rules
- Fixed Homework attempt rule
- Deadline if needed
- Assignment status
- Whether the Homework is designated as the official result-bearing Homework for the Topic

The Homework lifecycle status should control whether Students can access and complete the task. In the MVP, Homework lifecycle statuses are:

- Draft
- Active
- Closed
- Archived

Submission/review states such as submitted, waiting for Teacher review, and checked belong to the Student attempt/submission and must not be mixed with the Homework lifecycle.

The MVP version of **TestLabUz** should support the following assignment types:

1. **Single-choice test**  
   The student chooses one correct answer from several options.

2. **Multiple-choice test**  
   The student chooses more than one correct answer from several options.

3. **True / false question**  
   The student decides whether a statement is true or false.

4. **Short written answer**  
   The student writes a short answer, such as one word, one sentence, or a short explanation.

5. **Open written answer**  
   The student writes a longer explanation. This type of answer may need manual checking by the teacher.

6. **File-based assignment**  
   The Student uploads a file as an answer. In the MVP, supported answer file formats are PDF, DOCX, PPT, and PPTX. The platform hard maximum is **15 MB per file**, subject to any lower institution limit.

7. **Matching task**  
   The student matches items with the correct answers, such as terms with definitions.

8. **Ordering task**  
   The student puts steps, events, words, or items in the correct order.

9. **Fill-in-the-blank task**  
   The student fills in missing words, numbers, or values in a sentence or text.

The teacher should be able to create questions according to the selected assignment type. For example, a test question needs answer options and correct answers, while an open written answer needs instructions and manual checking rules.

Some assignment types can be checked automatically by the system. The approved MVP scoring behavior is:

- **Single-choice:** all-or-nothing
- **True / false:** all-or-nothing
- **Multiple-choice:** maximum Student selections equal the number of correct options; partial credit is based only on correctly selected options divided by total correct options
- **Matching:** partial credit per correctly matched pair
- **Ordering:** partial credit per correctly positioned item
- **Fill-in-the-blank:** partial credit per correctly completed blank

Short written answers may be checked automatically if the teacher defines exact accepted answers. However, if the answer requires explanation or judgment, the teacher may need to check it manually.

Open written answers and file-based assignments require Teacher judgment in the MVP. The Teacher should be able to open the submitted answer, review it, assign points within the allowed question maximum, and add feedback if needed. A Student answer must not be rewritten by the Teacher.

Each assignment should support points or score rules. The teacher should be able to define how many points each question is worth, or use a simple total score for the full assignment.

The system should calculate the homework score after the student submits the assignment. If all questions can be checked automatically, the system can calculate the score immediately. If some answers require manual checking, the assignment result should remain pending until the teacher reviews it.

Each Homework gives every assigned Student exactly **3 normal attempts**. This limit is fixed in the MVP and is not configured by the Institution Admin or Teacher.

Students should clearly see the current Homework attempt number and remaining attempts. The system stores all attempts separately and uses the **highest valid completed score** as the official Homework score after required checking is complete.

The system should prevent students from submitting new answers after all attempts are used, after the assignment is closed, or after the deadline has passed according to the assignment rules.

The Student should be able to view Homework instructions before starting. The instructions should explain what the Student needs to do, that **3 normal Homework attempts** are available, whether there is a deadline, and what type of answers are required.

The student should be able to start an assignment, answer questions, save progress if the platform design supports it, and submit the final answer.

After submission, the system should record important submission information, such as:

- Student
- Assignment
- Topic
- Group
- Attempt number
- Submitted answers
- Submitted file if applicable
- Submission time
- Score if available
- Checking status
- Teacher feedback if available

The system should support clear submission statuses. In the MVP version, possible statuses may include:

- Not started
- In progress
- Submitted
- Waiting for teacher review
- Checked
- Not completed
- Closed

These statuses help teachers, students, admins, and parents understand what happened with the assignment.

The teacher should be able to view assignment progress for a group. For example, the teacher should see which students have not started, which students are in progress, which students submitted, which submissions need manual checking, and which students did not complete the task.

The teacher should be able to review submissions by student, by group, by topic, and by assignment. This helps the teacher quickly identify who completed the homework and who needs additional support.

The student may be able to view their assignment result after automatic checking or teacher review, depending on teacher or institution settings. The result may include score, completion status, teacher feedback, and whether the assignment will be used in the final topic result.

Parents may be able to view whether their child completed the assignment, the homework score, checking status, and teacher feedback if available. Parents should not be able to submit or edit assignments for the student.

Institution Admins may be able to view assignment activity and completion statistics inside their own institution, but they should not normally complete assignments, change student answers, or replace the teacher’s checking role.

Assignments should be protected by access rules. Teachers should only manage assignments for their assigned groups or students. Students should only complete assignments assigned to them. Parents should only view their own child’s assignment progress. Users from another institution must not access the assignment or its submissions.

Assignments are also important because they are used together with blitz tasks. The homework assignment result shows how the student performed at home, while the blitz task result shows how the student performs in class. The system later compares both results to calculate the student’s real understanding level.

In the MVP version, Assignment features should include:

1. Create homework assignments
2. Connect assignments to topics
3. Assign homework to groups or students
4. Add assignment title
5. Add assignment description
6. Add student instructions
7. Add questions
8. Add answer options
9. Define correct answers
10. Define points or score rules
11. Support single-choice tests
12. Support multiple-choice tests
13. Support true / false questions
14. Support short written answers
15. Support open written answers
16. Support file-based assignments
17. Support matching tasks
18. Support ordering tasks
19. Support fill-in-the-blank tasks
20. Apply the fixed 3-attempt Homework rule
21. Add Homework deadline if needed
22. Manage Homework lifecycle status
23. Designate one Homework as the official result-bearing Homework for a Topic
24. Lock result-bearing task replacement after Student attempts begin
25. Allow Students to submit answers
26. Allow Students to upload files up to the effective 15 MB limit
27. Automatically check supported assignment types
28. Apply approved partial-credit rules
29. Allow Teachers to manually check written and file-based answers
30. Calculate each Homework attempt score
31. Select the highest valid completed Homework attempt as official
32. Show submission/review status
33. Show Homework completion status
34. Show remaining Homework attempts
35. Allow Teacher feedback
36. Show Homework progress to Teachers
37. Show released Homework results to Students
38. Show permitted Homework progress/results to Parents
39. Protect Homework access by institution, role, group, and user permissions

Advanced assignment features should be added later. These may include reusable question banks, random question selection, AI-generated assignments, AI answer checking, audio assignments, video assignments, coding tasks, group assignments, peer review, plagiarism checking, advanced rubrics, question difficulty levels, and integration with external learning systems.

The main purpose of Assignment features in the MVP is to let teachers create structured homework tasks, let students complete them, record the homework result, and prepare the system for comparing that result with the later blitz task result.

## 9. Blitz Task Features

Blitz tasks are one of the most important features in **TestLabUz**.

A blitz task is a short in-class task used to check whether a student truly understood a topic after completing the homework assignment at home.

The main purpose of the blitz task is to make the homework result more reliable. Since homework is completed outside the classroom, the teacher cannot always know whether the student completed it independently. A student may use outside help, copy answers, or complete the assignment without fully understanding the topic.

To verify the student’s real understanding, the teacher gives a short blitz task during the first 5–10 minutes of the next lesson. The blitz task is connected to the same topic as the homework assignment and contains short, focused, time-limited questions.

In the MVP version, blitz tasks will be created manually by teachers. AI-generated blitz tasks will not be included in the first version.

Each blitz task should be connected to:

- One institution
- One teacher
- One group or class
- One topic
- One homework assignment or homework result
- Assigned students
- Blitz questions
- Blitz submissions
- Blitz score
- Final understanding result

This connection is important because the system must compare the homework result and the blitz result for the same topic. The blitz task should not be separate from the learning process. It should be part of the topic-based learning-check workflow.

The teacher should be able to create a blitz task for their own assigned groups or students. Teachers should not be able to create blitz tasks for unrelated groups, other teachers’ groups, or another institution.

When creating a blitz task, the teacher should be able to add basic information such as:

- Blitz task title
- Topic
- Group or class
- Instructions for students
- Questions
- Answer options if needed
- Correct answers if needed
- Points or score rules
- Whole-Blitz duration
- Fixed normal-attempt rule
- Blitz status
- Start or activation settings
- Whether the Blitz is designated as the official result-bearing Blitz for the Topic

The blitz task should usually be short. Its purpose is not to replace the full homework assignment, but to quickly check whether the student understands the topic during class.

In the MVP version, a blitz task should support the same main assignment types used by the system, such as:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

However, because blitz tasks are short and time-limited, teachers should usually use faster task types for blitz activities, such as tests, true / false questions, short answers, matching tasks, ordering tasks, and fill-in-the-blank tasks.

Open written answers and file-based assignments may be supported, but they are less suitable for a 5–10 minute in-class blitz task. These types may require manual checking and should be used only when the teacher really needs them.

The Teacher should set one **whole-Blitz duration** for each Blitz. The MVP does not use per-question timers.

The Institution Admin chooses one institution-wide timer-start mode:

- **Synchronized start:** the timer starts for all assigned Students when the Teacher activates the Blitz.
- **Individual start:** Teacher activation makes the Blitz available, and each Student's timer begins when that Student starts the attempt.

The server is authoritative for time. Device clocks and device timezones cannot extend the Blitz.

Each Student normally receives exactly **1 Blitz attempt**. If a valid technical or other approved problem prevents proper completion, the Teacher may grant exactly **one additional Blitz attempt to that Student** and must provide a reason. The original interrupted/invalid attempt remains in history and is excluded from official scoring according to the approved exception.

When the timer reaches zero, the system stops accepting changes and **automatically finalizes saved answers**. Unanswered questions receive zero points. Saved answers are evaluated normally, and answers requiring Teacher judgment remain waiting for manual review.

The teacher should be able to keep a blitz task as a draft before class. A draft blitz task should not be visible to students.

The teacher should be able to start or activate the blitz task during class. Students should only be able to answer the blitz task when it is active.

The MVP Blitz lifecycle statuses are:

- Draft
- Scheduled
- Active
- Closed
- Archived

Student-level submission/review states such as in progress, submitted, waiting for Teacher review, checked, auto-finalized at timeout, or not completed are tracked separately from the Blitz lifecycle.

During class, the teacher should be able to monitor blitz progress. For example, the teacher should see:

- Which students have access to the blitz task
- Which students have started
- Which students are answering
- Which students submitted
- Which students did not submit
- Which submissions need manual checking
- Which students had technical or attempt issues if available

This helps the teacher manage the blitz task during the first minutes of the lesson.

Students should only see blitz tasks assigned to them. A student should not be able to access a blitz task before the teacher activates it. A student should not be able to answer a closed blitz task or a blitz task from another group.

The Student should be able to open the Teacher-activated Blitz, read the instructions, see the whole-Blitz remaining time, answer questions, and submit before timeout. If the Student does not explicitly submit before time reaches zero, the system automatically finalizes the saved work.

After the student submits the blitz task, the system should record important submission information, such as:

- Student
- Institution
- Group
- Topic
- Blitz task
- Attempt number
- Submitted answers
- Submission time
- Time spent
- Score if available
- Checking status
- Teacher feedback if available

Some blitz questions can be checked automatically by the system. These may include:

- Single-choice tests
- Multiple-choice tests
- True / false questions
- Matching tasks
- Ordering tasks
- Fill-in-the-blank tasks

Short written answers may be checked automatically if the teacher defines exact accepted answers. If the answer requires teacher judgment, it may need manual checking.

Open written answers and file-based blitz submissions may require manual checking by the teacher. The teacher should be able to review the answer, assign a score, and add feedback if needed.

After the blitz task is checked, the system should calculate the blitz score. This score will later be compared with the homework score for the same topic.

The system should show the teacher both results:

- Homework score
- Blitz score

If the homework score and blitz score are close to each other, the system should calculate the average score as the final result.

If there is a big difference between the homework score and the blitz score, the system should use the blitz score as the student’s real result.

This comparison is the main reason blitz tasks exist in **TestLabUz**. The blitz result helps the teacher understand whether the homework score reflects real knowledge or not.

The teacher should be able to view blitz results by topic, group, and student. The teacher should also be able to identify students who performed well on homework but poorly on the blitz task. These students may need additional revision or teacher support.

The student may be able to view their own blitz result after the task is checked, depending on teacher or institution settings.

Parents may be able to view the child’s blitz result, completion status, final result, and understanding category if allowed by the institution.

Institution Admins may be able to view blitz activity and progress inside their own institution, but they should not normally answer blitz tasks, change student submissions, or replace the teacher’s checking role.

Blitz tasks should be protected by access rules. Teachers should only manage blitz tasks for their assigned groups. Students should only answer blitz tasks assigned to them. Parents should only view their own child’s blitz progress. Users from another institution must not access the blitz task or its submissions.

In the MVP version, Blitz Task features should include:

1. Create manual blitz tasks
2. Connect blitz tasks to topics
3. Connect blitz tasks to homework results
4. Assign blitz tasks to groups or students
5. Add blitz task title
6. Add student instructions
7. Add blitz questions
8. Add answer options if needed
9. Define correct answers if needed
10. Define points or score rules
11. Configure whole-Blitz duration
12. Use institution-configured synchronized or individual timer-start mode
13. Apply the fixed 1 normal Blitz attempt rule
14. Allow one Student-specific additional Blitz attempt when Teacher-approved with a reason
15. Save Blitz task as draft
16. Schedule Blitz task if needed
17. Start or activate Blitz task during class
18. Close Blitz task
19. Designate one Blitz as the official result-bearing Blitz for a Topic
20. Lock result-bearing Blitz replacement after Student attempts begin
21. Allow Students to answer only after activation
22. Show whole-Blitz remaining time to Students
23. Auto-finalize saved answers when time ends
24. Give zero for unanswered questions at timeout
25. Allow Students to submit before timeout
26. Automatically check supported question types
27. Apply approved partial-credit rules
28. Allow Teachers to manually check written or file-based answers
29. Calculate official Blitz score
30. Show Blitz submission/review status
31. Show Blitz completion status
32. Show Blitz progress to Teachers during class
33. Show technical-attempt exception status where applicable
34. Show official Homework and Blitz scores together
35. Use approved Homework–Blitz formula for final result
36. Show released Blitz result to Students
37. Show permitted Blitz result to Parents
38. Protect Blitz access by institution, role, group, and user permissions

Advanced blitz task features should be added later. These may include AI-generated blitz questions, random question selection, anti-cheating tools, live classroom mode, QR-code entry, real-time analytics, automatic difficulty adjustment, question banks, device monitoring, and advanced classroom reports.

The main purpose of Blitz Task features in the MVP is to give teachers a simple and reliable way to verify whether students truly understood the topic after completing homework at home.

## 10. Result and Assessment Features

Result and assessment features are the main part of the learning-check logic in **TestLabUz**.

The purpose of these features is to help teachers understand the student’s real level of understanding for each topic. The system should not rely only on homework results, because homework is completed outside the classroom and may not always show the student’s real knowledge.

In **TestLabUz**, the final result should be based on both:

- Homework result
- Blitz task result

The homework result shows how the student performed after studying the topic and completing the assigned task at home. The blitz result shows how the student performed during a short in-class task connected to the same topic.

The system should compare these two results to decide whether the homework score is reliable.

If the homework score and blitz score are close to each other, the system should calculate the average score. This means the student’s homework result and in-class result are consistent.

If there is a big difference between the homework score and blitz score, the system should use the blitz score as the student’s real result. This means the student’s homework result may not fully reflect their real understanding.

The system should support a configurable rule for deciding what “close” and “big difference” mean. Different institutions may want to use different score gap rules.

For example, one institution may decide that a difference of 10 points is acceptable, while another institution may use 15 or 20 points. The exact rule should be configurable in the institution settings.

The basic result calculation logic should work like this:

1. The student completes the homework assignment.
2. The homework score is recorded.
3. The student completes the blitz task.
4. The blitz score is recorded.
5. The system compares the homework score and blitz score.
6. If the difference is within the allowed range, the system calculates the average score.
7. If the difference is bigger than the allowed range, the system uses the blitz score as the final result.
8. The system converts the final result into an understanding category.

Homework–Blitz comparison, threshold evaluation, and final-score calculation must use **unrounded internal score values**. User-facing score values are displayed with **one decimal place** using standard mathematical rounding. Understanding-category assignment uses a derived integer `category_score`: fractional parts `.0` through `.5` round down, and values greater than `.5` round up.

The final result should be shown as both a numeric score and an understanding category.

Understanding categories help teachers, students, and parents understand the result more clearly than a number alone.

In the MVP version, the system should support the following understanding categories:

1. **Understood well**  
   The student has a strong understanding of the topic.

2. **Partially understood**  
   The student understands some parts of the topic but still has gaps or mistakes.

3. **Needs revision**  
   The student has weak understanding and needs to review the material again.

4. **Needs teacher support**  
   The student has serious difficulty and may need additional explanation from the teacher.

5. **Not completed**  
   The student did not complete the required homework assignment, blitz task, or both.

The score ranges for the first four numeric understanding categories should be configurable by the **Institution Admin**. The **Not completed** category is non-numeric and is used only when required work can no longer validly be completed.

For example, one institution may define the categories like this:

- 86–100: Understood well
- 66–85: Partially understood
- 50–65: Needs revision
- 0–49: Needs teacher support
- Missing required task: Not completed

This is only an example. The final score ranges should be controlled by institution settings.

The system should clearly show whether the homework result and blitz result are consistent. This is important because consistency helps the teacher understand whether the homework score can be trusted.

For example:

- High homework score + high blitz score = strong consistency
- Medium homework score + medium blitz score = normal consistency
- High homework score + low blitz score = possible outside help or weak real understanding
- Low homework score + high blitz score = possible improvement or homework problem
- Missing homework or missing blitz = incomplete learning-check process

The teacher should be able to view the full result details for each student, including:

- Topic
- Homework assignment
- Homework score
- Blitz task
- Blitz score
- Score difference
- Final calculated score
- Understanding category
- Completion status
- Attempt information
- Teacher feedback if available

The teacher should be able to filter students by understanding category. This helps the teacher quickly identify which students are ready to move forward and which students need more support.

The teacher should be able to see students who have a big difference between homework and blitz scores. These students may need additional attention because their homework result may not show their real knowledge.

The Student should view the Topic result only after it is released according to the institution's Student result-release mode: **automatic after full calculation** or **manual Teacher release**.

The Parent should view the child's Topic result only according to the institution's Parent result-visibility mode: **with Student**, **manual Teacher release**, or **hidden**. Parent visibility must never begin before Student release.

The Institution Admin should be able to view general result and category information for their own institution. For example, they may view group-level or institution-level progress, but they should not normally change individual student answers or manually manipulate learning results.

The Platform Owner / Super Admin may view platform-level statistics, but should not normally interfere with institution-level learning results unless support, security, or system management requires it.

The system should handle incomplete results clearly. If the homework is completed but the blitz task is not completed, the result should show that the learning-check process is incomplete. If the blitz task is completed but homework is missing, the system should also show an incomplete status according to institution rules.

Manual checking should also be handled correctly. If an assignment or blitz task includes open written answers or file-based submissions, the final result should not be fully calculated until the teacher finishes checking the required answers.

The system should support clear result calculation statuses separately from visibility. In the MVP version, result calculation statuses include:

- Waiting for homework
- Waiting for blitz task
- Waiting for teacher review
- Calculated
- Not completed
- Closed

These statuses help teachers, students, parents, and admins understand where the result is in the learning-check process.

The system should protect result data. Students should only see their own results. Parents should only see their own child’s results. Teachers should only see results for assigned groups and students. Institution Admins should only see results inside their own institution. Users from another institution must not access result data.

In the MVP version, Result and Assessment features should include:

1. Record all valid Homework attempt scores
2. Select the highest valid completed Homework attempt as official
3. Record the official Blitz score
4. Compare only the designated official Homework and Blitz pair
5. Calculate the absolute score difference using unrounded values
6. Use the institution-configured acceptable score-difference threshold
7. Use average score when `D <= T`
8. Use Blitz score when `D > T`
9. Calculate and store the final result without premature rounding
10. Assign understanding category using the derived integer `category_score`
11. Display user-facing scores with one decimal place
12. Configure understanding-category score ranges
13. Show official Homework score to Teacher
14. Show official Blitz score to Teacher
15. Show final result to Teacher
16. Show understanding category to Teacher
17. Show result consistency status
18. Show incomplete/waiting result status
19. Keep calculation status separate from result visibility
20. Support Student release mode: automatic or manual Teacher
21. Support Parent visibility mode: with Student, manual Teacher, or hidden
22. Prevent Parent visibility before Student release
23. Show group-level result overview
24. Filter Students by understanding category
25. Identify Students who need revision
26. Identify Students who need Teacher support
27. Identify Students with large Homework/Blitz score differences
28. Wait for Teacher review before final calculation when manual checking is required
29. Preserve the threshold/category rules used for historical results
30. Protect result access by institution, role, group, Student, and Parent relationship

Advanced result and assessment features should be added later. These may include advanced analytics, learning trends, AI-based recommendations, risk prediction, automatic intervention suggestions, detailed reports, comparison between groups, teacher performance insights, and long-term student progress analysis.

The main purpose of Result and Assessment features in the MVP is to make student understanding clear, reliable, and useful for teachers, students, parents, and institution admins.

## 11. Reports and Progress Tracking Features

Reports and progress tracking features help users understand what is happening in the learning process.

The main purpose of these features is to show clear information about topics, homework assignments, blitz tasks, scores, completion status, final results, and understanding categories.

In the MVP version, reports should stay simple and practical. The system should not include advanced analytics, predictions, AI-based recommendations, or complex dashboards too early. The first version should focus on basic progress visibility for teachers, students, parents, Institution Admins, and the Platform Owner / Super Admin.

Reports should help answer important questions such as:

- Which students completed the homework?
- Which students completed the blitz task?
- Which students did not complete required tasks?
- Which students understood the topic well?
- Which students need revision?
- Which students need teacher support?
- Which students have a big difference between homework and blitz scores?
- Which groups are progressing well?
- Which topics are difficult for students?
- Which assignments or blitz tasks are waiting for teacher review?

The system should show progress at different levels:

1. Platform level
2. Institution level
3. Group or class level
4. Topic level
5. Student level
6. Parent-child level

The **Platform Owner / Super Admin** should be able to view basic platform-level reports. These reports should show general information about the whole platform, not detailed daily learning data from every institution.

Super Admin reports may include:

- Total number of institutions
- Active institutions
- Inactive institutions
- Total users
- Active users
- Institution activity overview
- Basic usage statistics
- Institutions that may need support

The Super Admin should not normally use reports to interfere with teacher-created content, student answers, or class results unless there is a support, security, or system management reason.

The **Institution Admin** should be able to view reports for their own institution only. Institution Admins should not see reports from other institutions.

Institution Admin reports should help them understand how their institution is using the system. These reports may include:

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
- Student progress overview
- Group progress overview
- Understanding category distribution
- Students or groups that may need attention

Institution Admins should be able to see which groups are active, which groups have low completion, and which groups have many students in “Needs revision” or “Needs teacher support” categories.

The Institution Admin should be able to view basic teacher activity, such as whether teachers are creating topics, uploading materials, assigning homework, giving blitz tasks, and reviewing submissions.

However, the Institution Admin should not normally change student answers, manually manipulate scores, or replace the teacher’s checking role. Their reports should be used mainly for management, support, and monitoring.

The **Teacher** should have the most important progress tracking features because teachers are responsible for the core learning-check process.

Teacher reports should help the teacher understand how students are performing for each topic, homework assignment, blitz task, and group.

Teacher reports may include:

- Assigned groups
- Active topics
- Topic progress
- Homework completion status
- Blitz completion status
- Homework scores
- Blitz scores
- Final calculated results
- Understanding categories
- Students waiting for manual review
- Students who did not complete homework
- Students who did not complete blitz tasks
- Students with large homework/blitz score differences
- Students who need revision
- Students who need teacher support

The teacher should be able to view progress by topic. A topic report should show how students performed on the homework assignment and blitz task connected to that topic.

A topic progress report may include:

- Topic title
- Group or class
- Teacher
- Number of assigned students
- Number of students who completed homework
- Number of students who completed the blitz task
- Number of students waiting for review
- Average homework score
- Average blitz score
- Average final result
- Understanding category distribution
- List of students who need support

The teacher should also be able to view progress by group or class. A group report should show how the group is performing across topics and tasks.

A group progress report may include:

- Group name
- Number of students
- Active topics
- Completed topics
- Homework completion rate
- Blitz completion rate
- Average final result
- Students with incomplete tasks
- Students with low understanding categories
- Topics where many students struggled

The teacher should be able to view individual student progress. A student progress report should show how one student is performing across assigned topics.

A student progress report may include:

- Student name
- Group or class
- Assigned topics
- Homework completion status
- Blitz completion status
- Homework scores
- Blitz scores
- Final results
- Understanding categories
- Attempts used
- Teacher feedback if available
- Topics that need revision
- Topics that need teacher support

The teacher should be able to filter reports. In the MVP version, simple filters may include:

- Group or class
- Topic
- Subject
- Student
- Completion status
- Understanding category
- Task status
- Date range if needed

The teacher should also be able to quickly find tasks that require action. For example, the system should show submissions waiting for manual checking, students who did not complete tasks, and students with weak results.

The **Student** should be able to view their own progress only. Students should not see other students’ scores, answers, private progress, or personal information.

Student progress tracking should help students understand:

- Which topics are assigned to them
- Which homework tasks they completed
- Which blitz tasks they completed
- Which tasks are still not completed
- Their homework scores
- Their blitz scores
- Their final results
- Their understanding categories
- Which topics need more revision

Student progress should be simple and easy to understand. The system should clearly show whether a topic is completed, waiting for review, not completed, or needs revision.

The **Parent** should be able to view progress for their own child or children only. Parents should not see other students’ data or teacher-private information.

Parent progress tracking should help parents understand:

- Which topics their child is studying
- Whether homework was completed
- Whether the blitz task was completed
- Homework score
- Blitz score
- Final result
- Understanding category
- Topics where the child needs revision
- Topics where the child needs teacher support
- Teacher feedback if available

If a parent has more than one child connected to their account, the parent should be able to switch between children and view each child’s progress separately.

Reports should clearly show completion status. In the MVP version, the system may use statuses such as:

- Not started
- In progress
- Submitted
- Waiting for teacher review
- Checked
- Completed
- Not completed
- Closed

Reports should also show result statuses when needed. For example:

- Waiting for homework
- Waiting for blitz task
- Waiting for teacher review
- Calculated
- Not completed
- Closed

The system should show understanding categories in reports because categories are easier to act on than raw scores alone.

The MVP version should support these categories:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

Reports should also show when homework and blitz results are not consistent. For example, if a student has a high homework score but a low blitz score, the teacher should be able to see this clearly. This helps the teacher identify students whose homework result may not reflect real understanding.

Reports should support basic summaries, not only detailed lists. For example, a teacher should be able to see how many students are in each understanding category for a topic or group.

The system should protect all report data with role-based access rules. Each user should only see report information that belongs to their institution, role, group, student relationship, and permission scope.

In the MVP version, Reports and Progress Tracking features should include:

1. View platform-level basic reports for Super Admin
2. View institution-level basic reports for Institution Admin
3. View teacher dashboard progress
4. View student dashboard progress
5. View parent dashboard progress
6. View topic progress reports
7. View group or class progress reports
8. View individual student progress reports
9. View child progress reports for parents
10. Show homework completion status
11. Show blitz completion status
12. Show homework scores
13. Show blitz scores
14. Show final calculated results
15. Show understanding categories
16. Show result consistency between homework and blitz
17. Show students who did not complete homework
18. Show students who did not complete blitz tasks
19. Show submissions waiting for teacher review
20. Show students who need revision
21. Show students who need teacher support
22. Show students with large homework/blitz score differences
23. Show group-level completion overview
24. Show topic-level completion overview
25. Show basic institution progress overview
26. Filter reports by group or class
27. Filter reports by topic
28. Filter reports by student
29. Filter reports by completion status
30. Filter reports by understanding category
31. Show teacher feedback if available
32. Protect report access by institution, role, group, student, and parent relationship

Advanced reports and analytics should be added later. These may include long-term learning trends, predictive analytics, AI recommendations, advanced charts, downloadable reports, report exports, teacher performance insights, topic difficulty analysis, comparison between groups, automatic weekly summaries, and parent notifications.

The main purpose of Reports and Progress Tracking features in the MVP is to make learning progress visible, understandable, and useful without making the first version too complex.

## 12. Access, Security, and Data Separation Features

Access, security, and data separation features are essential parts of **TestLabUz**.

Because the platform will support many educational institutions from the beginning, the system must make sure that each user can only access the information and actions that belong to their role, institution, group, and relationship.

The main purpose of these features is to protect institution data, student privacy, uploaded learning materials, assignments, blitz tasks, scores, reports, and user accounts.

The most important access rule in **TestLabUz** is:

**Each user can only access data inside their allowed scope.**

The system should support role-based access control. This means every user should have a role, and that role defines what the user can view, create, edit, delete, manage, or submit.

The MVP version will include the following main roles:

1. Platform Owner / Super Admin
2. Institution Admin
3. Teacher
4. Student
5. Parent

Each role should have a clear access level.

The **Platform Owner / Super Admin** can manage the whole platform. This role can create institutions, view all institutions, activate or deactivate institutions, view basic platform statistics, manage global settings, and support institutions when needed.

However, the Super Admin should not normally interfere with daily learning data. For example, the Super Admin should not usually change student answers, teacher-created assignments, blitz tasks, or class results unless there is a support, security, or system management reason.

The **Institution Admin** can manage only their own institution. This role can manage users, groups, Teachers, Students, Parents, institution settings, category ranges, acceptable score-difference threshold, Blitz timer-start mode, result-release modes, institution timezone, effective upload limits, and basic reports inside the institution.

Institution Admins must not be able to access another institution’s users, groups, topics, assignments, blitz tasks, submissions, results, reports, or settings.

The **Teacher** can manage only assigned groups, topics, assignments, blitz tasks, and student results. Teachers should not access unrelated groups, another teacher’s private teaching data, another institution’s data, or institution-wide settings unless explicitly allowed.

Teachers should be able to create and manage learning content only inside their teaching scope.

The **Student** can access only their own assigned topics, learning materials, homework assignments, blitz tasks, submissions, scores, understanding categories, and personal learning progress.

Students must not be able to view other students’ answers, scores, private progress, parent information, teacher-only reports, or institution settings.

The **Parent** can access only the learning progress of their own child or children. Parents should not be able to access other students’ data, other parents’ data, teacher-private notes, internal reports, or institution settings.

Parents should only have view access. They should not complete tasks, answer blitz questions, upload assignment files, change answers, change scores, or edit learning results.

The system should clearly separate **view access** and **edit access**.

For example:

- A parent may view a child’s result, but cannot edit it.
- A student may view their own score, but cannot change it.
- A teacher may review results for assigned students, but cannot manage institution-wide settings.
- An Institution Admin may manage users and settings, but should not change student submissions.
- A Super Admin may manage institutions, but should not normally change daily learning data.

The system should also protect important actions with permissions.

Important protected actions may include:

- Creating users
- Editing users
- Activating users
- Deactivating users
- Creating groups
- Editing groups
- Assigning students to groups
- Assigning teachers to groups
- Connecting parents to students
- Creating topics
- Editing topics
- Uploading learning materials
- Removing learning materials
- Creating homework assignments
- Editing homework assignments
- Creating blitz tasks
- Starting or activating blitz tasks
- Closing blitz tasks
- Checking manual answers
- Granting a Student-specific Blitz attempt exception
- Changing assessment category settings
- Changing acceptable score-difference threshold
- Changing Blitz timer-start mode
- Changing Student result-release mode
- Changing Parent result-visibility mode
- Changing institution timezone
- Changing institution upload limits within platform maximums
- Viewing reports
- Activating institutions
- Deactivating institutions

The system should protect data between institutions. Since **TestLabUz** is a multi-institution platform, each institution’s data must remain separate and private.

This means one institution should not see another institution’s:

- Users
- Groups or classes
- Teachers
- Students
- Parents
- Topics
- Learning materials
- Homework assignments
- Blitz tasks
- Submissions
- Scores
- Understanding categories
- Reports
- Settings

Every important record in the system should belong to the correct institution. This includes users, groups, topics, materials, assignments, blitz tasks, submissions, results, reports, and settings.

The system should also protect group-level access. For example, a teacher assigned to Group A should not automatically access Group B unless they are also assigned to that group.

Students should only receive topics, assignments, and blitz tasks assigned to their group or directly assigned to them.

Parents should only see results for students connected to their parent account.

The system should protect uploaded files. Learning materials and submitted assignment files should only be accessible to users with permission.

For example:

- Teachers can manage materials for their own topics.
- Students can open materials assigned to them.
- Students can upload files only for their own file-based assignments.
- Teachers can review submitted files for their assigned students.
- Parents may view file-related progress if allowed, but should not edit or replace files.
- Users from another institution must not access uploaded files.

The system should protect submissions and scores. Student answers, submitted files, homework scores, blitz scores, final results, and understanding categories should only be visible to allowed users.

The system should prevent unauthorized changes to submissions after the task is closed, after the time limit ends, or after allowed attempts are used.

The system should also protect blitz tasks carefully. A student should only access a blitz task when the teacher starts or activates it. Students should not access inactive, closed, archived, or unrelated blitz tasks.

If a user tries to access information outside their allowed scope, the system should block the action and show a clear message.

For example:

- “You do not have permission to access this page.”
- “This task is not assigned to you.”
- “This blitz task is not active.”
- “You cannot access data from another institution.”
- “You cannot edit this record.”

The system should support secure authentication. Users should log in with their own account and should not share access. Each account should be connected to the correct role and institution.

In the MVP version, the system should include basic account security, such as login, logout, password protection, active/inactive user status, and role-based access.

The system should support account activation and deactivation. If a user is deactivated, they should not be able to use the platform normally until their account is activated again.

The system should also support institution activation and deactivation. If an institution is deactivated, users from that institution should not be able to continue using the platform normally until the institution is activated again.

The system should protect reports with the same access rules. Reports should only show data that belongs to the user’s allowed scope.

For example:

- Super Admin sees platform-level reports.
- Institution Admin sees only their own institution reports.
- Teacher sees only assigned groups and students.
- Student sees only personal progress.
- Parent sees only connected child progress.

The system should keep the MVP security model simple but correct. Advanced enterprise security features can be added later, but the first version must still protect user data and institution separation properly.

In the MVP version, Access, Security, and Data Separation features should include:

1. User login
2. User logout
3. Role-based access control
4. Institution-based data separation
5. Group-based access control
6. Parent-child access control
7. Teacher-assigned group access
8. Student-assigned task access
9. Permission protection for important actions
10. Separate view and edit permissions
11. Protect uploaded learning materials
12. Protect submitted assignment files
13. Protect homework submissions
14. Protect blitz submissions
15. Protect scores and final results
16. Protect understanding categories
17. Protect reports by role and scope
18. Block access to another institution’s data
19. Block access to unrelated group data
20. Block students from viewing other students’ data
21. Block parents from viewing unrelated children’s data
22. Block inactive users from using the platform
23. Block users from deactivated institutions
24. Show clear permission error messages
25. Keep each record connected to the correct institution
26. Keep each topic connected to the correct group and teacher
27. Keep each assignment connected to the correct topic
28. Keep each blitz task connected to the correct topic and group
29. Keep each result connected to the correct student
30. Keep each parent connected only to allowed children

Advanced security features should be added later. These may include two-factor authentication, detailed audit logs, advanced permission groups, custom roles, session management, suspicious activity detection, IP restrictions, device management, advanced file scanning, and enterprise security settings.

The main purpose of Access, Security, and Data Separation features in the MVP is to make sure **TestLabUz** is safe, organized, and reliable for many educational institutions using the same platform.

## 13. Platform Access by Device

Platform access by device defines which user roles should use **TestLabUz** on desktop, mobile, or both.

The purpose of this stage is to make sure each role gets the right interface for their real work. Some users need large screens, tables, filters, file management, and dashboards. Other users need a simple mobile interface for quick access and progress monitoring.

In the MVP version, the platform should support different access types for different roles:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

The **Platform Owner / Super Admin** should use the desktop version of the platform.

This role manages the whole platform, institutions, platform-level settings, institution status, support issues, and basic platform statistics. These actions require management screens, data tables, filters, dashboards, and detailed controls. Because of this, Super Admin access should be designed for desktop in the MVP version.

The Super Admin desktop interface may include:

- Platform dashboard
- Institution list
- Institution details
- Create institution screen
- Edit institution screen
- Institution activation and deactivation tools
- Basic platform statistics
- Support and issue overview
- Global platform settings

The **Institution Admin** should also use the desktop version of the platform.

Institution Admins manage one educational institution. They work with users, groups, Teachers, Students, Parents, role access, category ranges, score-difference threshold, Blitz timer-start mode, result-release modes, institution timezone, upload limits, and basic institution reports. These actions are more suitable for desktop because they often require large tables, forms, filters, and management tools.

The Institution Admin desktop interface may include:

- Institution dashboard
- User management
- Teacher management
- Student management
- Parent management
- Group or class management
- Parent-student connection management
- Teacher-group assignment
- Student-group assignment
- Assessment category settings
- Homework–Blitz score-difference threshold
- Blitz timer-start mode
- Student result-release mode
- Parent result-visibility mode
- Institution timezone
- Institution upload limits
- Basic institution reports

The **Teacher** should have both desktop and mobile access.

Teachers need the desktop version for larger and more detailed work. Creating topics, uploading learning materials, building assignments, creating blitz tasks, checking written answers, reviewing file submissions, and analyzing reports are easier on desktop.

The Teacher desktop interface may include:

- Teacher dashboard
- Assigned groups
- Student lists
- Topic management
- Learning material upload
- Homework assignment builder
- Blitz task builder
- Manual answer checking
- File submission review
- Topic progress reports
- Group progress reports
- Student progress reports

Teachers should also have mobile access for quick actions during or outside class. The mobile version should not replace the full desktop interface, but it should help teachers perform important simple actions quickly.

The Teacher mobile interface may include:

- View assigned groups
- View topic status
- View homework completion status
- Start or activate blitz tasks
- Monitor blitz task progress during class
- View students who submitted
- View students who did not submit
- View basic student results
- View students who need revision or teacher support

The **Student** should have both desktop and mobile access.

Students may use the desktop version when they need a larger screen for studying materials, writing longer answers, completing complex tasks, uploading files, or working with document-based assignments.

The Student desktop interface may include:

- Student dashboard
- Assigned topics
- Learning materials
- Homework assignments
- Written answer tasks
- File-based assignments
- Assignment submission screens
- Personal progress overview

Students should also have mobile access because many students may study materials, answer simple tests, complete short tasks, and participate in blitz tasks from a mobile device.

The Student mobile interface may include:

- View assigned topics
- Open learning materials
- Complete simple homework tasks
- Answer tests
- Answer true / false questions
- Answer matching tasks
- Answer fill-in-the-blank tasks
- Join active blitz tasks
- View remaining blitz time
- Submit blitz answers
- View own scores and understanding categories

The **Parent** should use the mobile version of the platform.

Parents mainly need to monitor their child’s learning progress. They do not need complex management tools, content creation screens, or detailed admin panels. Their interface should be simple, fast, and focused on viewing important information.

The Parent mobile interface may include:

- Parent dashboard
- Connected child or children
- Child progress overview
- Assigned topics
- Homework completion status
- Blitz completion status
- Homework score
- Blitz score
- Final result
- Understanding category
- Teacher feedback if available
- Topics that need revision
- Topics that need teacher support

In the MVP version, parents should not need a desktop interface.

Each device version should show only the features that are relevant to the user’s role. For example, parents should not see teacher tools, students should not see admin tools, and admins should not see student task-completion screens.

The system should also protect access across devices. A user should not be able to access restricted features just because they use a different device. Role permissions, institution scope, group scope, and parent-child relationships should remain the same on desktop and mobile.

For example:

- A student using desktop still cannot view other students’ scores.
- A parent using mobile still cannot change learning results.
- A teacher using mobile still cannot access unrelated groups.
- An Institution Admin using desktop still cannot access another institution’s data.
- A Super Admin using desktop still should not normally interfere with daily learning data.

The MVP should not try to make every feature available on every device. This would make the first version more complex and harder to build. Instead, each device version should focus on the most important actions for that role.

In the MVP version, Platform Access by Device features should include:

1. Desktop access for Platform Owner / Super Admin
2. Desktop access for Institution Admin
3. Desktop access for Teacher
4. Mobile access for Teacher
5. Desktop access for Student
6. Mobile access for Student
7. Mobile access for Parent
8. Role-based feature visibility by device
9. Permission protection across desktop and mobile
10. Super Admin desktop dashboard
11. Institution Admin desktop dashboard
12. Teacher desktop dashboard
13. Teacher mobile quick actions
14. Student desktop learning and task completion
15. Student mobile learning and blitz participation
16. Parent mobile progress monitoring
17. Consistent institution-based access control on all devices
18. Consistent group-based access control on all devices
19. Consistent parent-child access control on mobile
20. Clear separation between management screens, teaching screens, learning screens, and monitoring screens

Advanced device features should be added later. These may include offline mode, push notifications, tablet-optimized layouts, desktop notifications, mobile biometric login, responsive web dashboards, and role-specific native mobile improvements.

The main purpose of Platform Access by Device features in the MVP is to give each user role the right interface for their real responsibilities without making the first version unnecessarily complex.

## 14. MVP Feature Scope

The MVP feature scope defines what should be included in the first version of **TestLabUz**.

The purpose of the MVP is to build a simple, practical, and usable version of the platform that proves the core idea: teachers can create topics, upload learning materials, assign homework, give short blitz tasks during class, compare homework and blitz results, and understand the student’s real learning level.

The MVP should not try to include every possible education feature from the beginning. The first version should focus only on the features needed to make the main learning-check workflow work from beginning to end.

The MVP should support multiple educational institutions from the beginning. Each institution should have its own users, groups, topics, materials, assignments, blitz tasks, submissions, results, settings, and reports. Data from one institution must remain separate from data from another institution.

The MVP should include five main roles:

1. Platform Owner / Super Admin
2. Institution Admin
3. Teacher
4. Student
5. Parent

The **Platform Owner / Super Admin** should be able to manage the whole platform at a basic level. This includes viewing the platform dashboard, creating institutions, viewing institutions, editing basic institution information, activating or deactivating institutions, viewing basic platform statistics, and supporting Institution Admins when needed.

The **Institution Admin** should be able to manage one educational institution. This includes managing Teachers, Students, Parents, groups or classes, Parent–Student connections, Teacher–group assignments, Student–group assignments, assessment category settings, acceptable Homework–Blitz difference threshold, Blitz timer-start mode, result-release modes, institution timezone, lower upload limits, and basic institution reports.

The **Teacher** should be able to manage the core learning process. This includes creating Topics, uploading learning materials, creating Homework assignments, creating Blitz tasks, setting Homework deadlines, setting whole-Blitz duration, designating the official Homework/Blitz pair before attempts begin, activating Blitz tasks, granting one allowed Student-specific Blitz exception, reviewing submissions, checking manual answers, reviewing results, and releasing results when institution policy requires Teacher action.

The **Student** should be able to study assigned materials, complete homework assignments, answer active blitz tasks, upload files for file-based assignments, view completion status, view scores if allowed, and understand their own learning progress.

The **Parent** should be able to monitor their child’s progress from the mobile version. This includes viewing assigned topics, homework completion status, blitz results, scores, final results, understanding categories, teacher feedback if available, and topics where the child needs support.

The MVP should support topic management. Teachers should be able to create topics, edit their own topics, assign topics to groups or classes, add student instructions, manage topic status, and connect topics with learning materials, homework assignments, and blitz tasks.

The MVP should support learning material uploads in the following formats:

- PDF
- DOCX
- PPT
- PPTX

Teachers should be able to upload, view, update, replace, or remove materials for their own topics. Students should be able to open or download materials assigned to them.

The MVP should support the following assignment types:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

Teachers should be able to create homework assignments using these assignment types. Students should be able to submit answers according to the assignment rules.

The MVP should support automatic checking for assignment types where automatic checking is possible, such as tests, true / false questions, matching tasks, ordering tasks, and fill-in-the-blank tasks.

The MVP should also support manual checking for assignment types that require teacher review, such as open written answers and file-based assignments. Teachers should be able to assign scores and add feedback if needed.

The MVP should use the fixed attempt rules: **3 normal Homework attempts** with the highest valid completed score official, and **1 normal Blitz attempt** with at most **1 additional Student-specific Teacher-approved Blitz attempt** for a valid reason.

The MVP should support blitz tasks. Teachers should be able to manually create blitz tasks connected to the same topic as the homework assignment. Blitz tasks should be short, focused, and time-limited.

Teachers should be able to save blitz tasks as drafts, activate them during class, monitor student progress, close them, check submissions, and view blitz scores.

Students should only be able to answer Blitz tasks after Teacher activation. The system should apply the institution's synchronized or individual timer-start mode, show the whole-Blitz remaining time, and auto-finalize saved work at timeout while rejecting late changes.

The MVP should support result comparison. The system should record the homework score and blitz score for the same topic, compare both scores, calculate the score difference, and decide the final result according to institution rules.

If the homework score and blitz score are close to each other, the system should calculate the average score. If there is a big difference, the system should use the blitz score as the student’s real result.

The MVP should support configurable score difference rules. Each institution should be able to define what score difference is considered acceptable.

The MVP should support understanding categories. The system should convert the final result into a category, such as:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support
- Not completed

The score ranges for understanding categories should be configurable by institution.

The MVP should support basic reports and progress tracking. Reports should show homework completion, blitz completion, homework scores, blitz scores, final results, understanding categories, incomplete tasks, students waiting for teacher review, and students who need support.

Reports should be available according to role:

- Super Admin sees basic platform-level reports.
- Institution Admin sees basic institution-level reports.
- Teacher sees group, topic, and student progress.
- Student sees personal progress.
- Parent sees their child’s progress.

The MVP should support role-based access control, institution-based data separation, group-based access control, parent-child access control, and permission protection for important actions.

The MVP should protect uploaded files, submissions, scores, results, reports, and user accounts. Users from one institution must not access data from another institution.

The MVP should support the following device access model:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

Each device version should show only the features that are relevant to that user’s role.

In the MVP version, the main included feature groups are:

1. Multi-institution support
2. Role-based user access
3. Platform Owner / Super Admin management
4. Institution Admin management
5. Teacher learning workflow
6. Student learning workflow
7. Parent progress monitoring
8. Topic management
9. Learning material upload
10. Homework assignment creation
11. Nine supported assignment types
12. Assignment submissions
13. Automatic checking where possible
14. Manual teacher checking where needed
15. Fixed Homework and Blitz attempt rules
16. Student-specific Blitz technical-attempt exception
17. Manual Blitz task creation
18. Institution-configured Blitz timer-start mode
19. Teacher-configured whole-Blitz duration
20. Timeout auto-finalization
21. Approved partial-credit scoring
22. Official Homework and Blitz result-bearing pair
23. Homework and Blitz score comparison
24. Full-precision result calculation with one-decimal display
25. Understanding categories
26. Student and Parent result-release policies
27. Platform and institution upload-size limits
28. Institution timezone with authoritative UTC timestamps
29. Basic reports and progress tracking
30. Access control and data separation
31. Desktop and mobile access based on role

The MVP should exclude advanced features that are not required for proving the core idea. AI features, audio and video assignments, monetization, advanced analytics, communication tools, external integrations, complex customization, and advanced security features should be added later.

The main goal of the MVP feature scope is to keep the first version focused, realistic, and buildable while still supporting the complete core learning-check process of **TestLabUz**.

## 15. Future Feature Scope

The future feature scope defines which features should be added to **TestLabUz** after the MVP version is completed, tested, and improved based on real usage.

The MVP version should focus on the core learning-check workflow: topics, learning materials, homework assignments, blitz tasks, score comparison, final results, understanding categories, basic reports, and role-based access.

Future features should not be added too early. They should be added step by step after the main workflow works clearly, reliably, and simply for real educational institutions.

The purpose of future features is to make **TestLabUz** more powerful, more flexible, and more useful over time without making the first version too large or difficult to build.

One major future direction is **AI support**.

AI may help teachers create learning content faster. For example, AI may generate questions from uploaded PDF, DOCX, or PPT materials. It may also suggest homework assignments, blitz questions, explanations, summaries, and revision tasks based on the topic content.

Future AI features may include:

1. AI-generated questions from uploaded materials
2. AI-generated blitz tasks
3. AI-generated homework assignments
4. AI-generated topic summaries
5. AI-generated study notes for students
6. AI-based checking for written answers
7. AI-based feedback suggestions for teachers
8. AI recommendations for students who need revision
9. AI suggestions for students who need teacher support
10. AI analysis of common mistakes by topic or group

AI should not replace the teacher. The teacher should remain responsible for approving, editing, and using AI-generated content. AI should be used as an assistant, not as the main decision-maker.

Another future direction is **audio and video support**.

In the MVP version, learning materials will support PDF, DOCX, PPT, and PPTX files. In future versions, the system may support audio lessons, video lessons, voice explanations, recorded lectures, and video-based learning materials.

Future audio and video features may include:

1. Uploading audio lessons
2. Uploading video lessons
3. Recording voice explanations
4. Recording video explanations
5. Watching video materials inside the platform
6. Listening to audio materials inside the platform
7. Audio-based assignments
8. Video-based assignments
9. Student voice answers
10. Student video answers

These features may be especially useful for language learning, speaking practice, pronunciation tasks, presentation tasks, and subjects where visual explanation is important.

Future versions may also include more advanced assignment types.

The MVP already supports the main assignment types, but later the platform may support more specialized task formats.

Future assignment features may include:

1. Speaking tasks
2. Listening tasks
3. Video response tasks
4. Coding tasks
5. Project-based assignments
6. Group assignments
7. Peer review assignments
8. Rubric-based grading
9. Question difficulty levels
10. Randomized questions
11. Question banks
12. Reusable assignment templates
13. Plagiarism checking
14. Advanced file submission rules

Question banks can help teachers reuse questions across topics, groups, and future lessons. Randomized questions can help reduce copying and make homework or blitz tasks more reliable.

Future versions may include **advanced blitz task features**.

In the MVP, blitz tasks will be manually created by teachers and activated during class. Later, blitz tasks may become more dynamic and interactive.

Future blitz task features may include:

1. AI-generated blitz questions
2. Random blitz question selection
3. Live classroom mode
4. Real-time answer tracking
5. QR-code or access-code entry for blitz tasks
6. Anti-cheating tools
7. Device monitoring during blitz
8. Automatic difficulty adjustment
9. Live result display for the teacher
10. Advanced blitz reports

These features should be added only after the simple blitz workflow is tested and works well.

Another future direction is **advanced reports and analytics**.

The MVP should include basic reports and progress tracking. Future versions may include deeper analysis for teachers, admins, parents, and platform managers.

Future analytics features may include:

1. Long-term student progress tracking
2. Topic difficulty analysis
3. Group comparison
4. Subject-based progress reports
5. Teacher activity reports
6. Institution performance reports
7. Student learning trends
8. Homework/blitz consistency trends
9. Students at risk of falling behind
10. AI-based learning recommendations
11. Downloadable reports
12. Report export to Excel or PDF
13. Weekly progress summaries
14. Parent progress reports
15. Institution-level dashboards

Advanced analytics should help institutions understand which topics are difficult, which students need support, and which groups are progressing well.

Future versions may include **communication features**.

In the MVP, the platform should focus on learning tasks and progress tracking. Later, communication tools may be added to improve coordination between teachers, students, parents, and admins.

Future communication features may include:

1. Teacher-student comments
2. Teacher feedback threads
3. Teacher-parent messages
4. Institution announcements
5. Group announcements
6. Task reminders
7. Parent notifications
8. Student notifications
9. Admin notifications
10. Support messages

Communication features should be added carefully so the platform does not become too complex or turn into a general chat system too early.

Future versions may include **notifications and reminders**.

These features can help users stay informed about tasks, deadlines, blitz activities, results, and progress updates.

Future notification features may include:

1. Homework deadline reminders
2. Blitz task reminders
3. New topic notifications
4. New material notifications
5. Result notifications
6. Teacher review notifications
7. Parent progress notifications
8. Weekly child progress summaries
9. Admin activity alerts
10. Institution status alerts

Notifications may be delivered inside the app first. Later, they may be connected to email, SMS, Telegram, or push notifications.

Future versions may include **monetization features**.

At the beginning, **TestLabUz** will be free. Monetization should be added only after the MVP is tested and the real needs of institutions are better understood.

Future monetization features may include:

1. Subscription plans for institutions
2. Free and paid feature limits
3. Paid AI features
4. Paid advanced analytics
5. Paid storage limits
6. Paid premium support
7. Custom licenses for large institutions
8. Invoice management
9. Payment integration
10. Billing dashboard

Monetization should not block the MVP. The first goal is to build a useful product, test it with real institutions, and improve it based on feedback.

Future versions may include **external integrations**.

These integrations can help institutions connect **TestLabUz** with tools they already use.

Future integration features may include:

1. Google Classroom integration
2. Moodle integration
3. Telegram integration
4. Email integration
5. SMS integration
6. Google Drive integration
7. Microsoft OneDrive integration
8. Calendar integration
9. Payment system integration
10. External student information system integration

Integrations should be added only when there is real demand from institutions. They should not be part of the MVP.

Future versions may include **advanced institution customization**.

In the MVP, institutions will have basic settings. Later, institutions may need more control over branding, grading, workflows, and permissions.

Future customization features may include:

1. Institution logo
2. Institution colors
3. Custom grading rules
4. Custom understanding categories
5. Custom role permissions
6. Custom group structures
7. Custom report formats
8. Advanced custom task rules
9. Advanced Parent visibility workflows beyond the approved MVP modes
10. Advanced Student result-release workflows beyond the approved MVP modes

These features can make the platform more flexible for different types of institutions, but they should be added after the basic model is stable.

Future versions may include **additional user roles**.

The MVP includes Platform Owner / Super Admin, Institution Admin, Teacher, Student, and Parent. Later, more specialized roles may be added if real institutions need them.

Future roles may include:

1. Institution Owner / Director
2. Department Manager
3. Group / Class Curator
4. Assistant Teacher
5. Content Moderator
6. Platform Support Agent
7. Finance / Billing Manager
8. Report Viewer
9. Guest / Observer

These roles should not be added to the MVP unless they become necessary. The first version should keep the role system simple.

Future versions may include **advanced security features**.

The MVP must already protect data correctly, but later versions may need stronger security tools, especially when more institutions start using the platform.

Future security features may include:

1. Two-factor authentication
2. Advanced audit logs
3. Session management
4. Device management
5. Suspicious activity detection
6. IP restrictions
7. File scanning
8. Advanced permission groups
9. Custom roles
10. Enterprise security settings

Security improvements should be added step by step as the platform grows.

Future versions may include **offline and performance improvements**.

Teachers and students may sometimes have weak internet connections. In later versions, the platform may support limited offline access or better performance features.

Future offline and performance features may include:

1. Offline material access
2. Offline homework drafts
3. Auto-save for answers
4. Sync when internet returns
5. Faster file loading
6. Optimized mobile performance
7. Desktop performance improvements
8. Large institution optimization
9. Background upload support
10. Better handling of unstable connections

These features can make the platform more reliable for real classroom use.

Future versions may include **student motivation features**.

These features can help students stay engaged, but they should not distract from the main learning-check purpose.

Future motivation features may include:

1. Badges
2. Achievements
3. Progress streaks
4. Certificates
5. Personal learning goals
6. Revision suggestions
7. Topic completion milestones
8. Student progress timeline

These features should be added carefully so the platform remains educational and not only gamified.

Future versions may also include **content organization improvements**.

As institutions create more topics and assignments, teachers may need better tools for managing content.

Future content features may include:

1. Topic templates
2. Assignment templates
3. Reusable lesson structures
4. Reusable material libraries
5. Question banks
6. Subject-based content organization
7. Topic version history
8. Material version history
9. Content search
10. Content archive management

These features will become more important after the platform has many topics, materials, and assignments.

The future feature scope should remain flexible. Not every future feature must be built. Features should be selected based on real user feedback, institution needs, technical complexity, and business value.

The main future feature groups are:

1. AI features
2. Audio and video support
3. Advanced assignment types
4. Advanced blitz task features
5. Advanced reports and analytics
6. Communication tools
7. Notifications and reminders
8. Monetization features
9. External integrations
10. Advanced institution customization
11. Additional user roles
12. Advanced security features
13. Offline and performance improvements
14. Student motivation features
15. Content organization improvements

The main rule is simple: future features should improve the core product, not distract from it.

The MVP should first prove that **TestLabUz** can help teachers measure real student understanding by comparing homework results with blitz task results. After that, future features can be added step by step to make the platform more intelligent, flexible, scalable, and valuable for educational institutions.
## Post-Audit Feature Clarifications

The MVP feature contract also includes:

1. **Category score conversion:** result calculation remains unrounded, while category assignment uses an integer score with `.0`–`.5` down and `>.5` up. Institution category ranges are inclusive integer ranges covering 0–100.
2. **Multiple-choice selection cap:** Student UI receives `max_selections`, cannot select more than the number of correct options, and earns only the fraction of correct options selected.
3. **Automatic short-answer normalization:** normalized exact matching only; Unicode normalization, trim, whitespace collapse, case-insensitive comparison, Uzbek apostrophe normalization, punctuation preserved, no fuzzy/AI interpretation.
4. **Activation validation:** Homework/Blitz drafts may contain zero points during authoring but cannot activate until server-recalculated total possible points is greater than zero.
5. **Official grading scope:** official Homework/Blitz are whole-group only; selected-Student tasks are practice-only; one cohort snapshot is shared by both official tasks.
6. **New-institution setup:** safe timezone/upload defaults are initialized, while threshold/category/timer/release policies remain unconfigured until the Institution Admin selects them.
7. **First-login password change:** all administrator-created non-platform accounts must change the initial password before normal use.
8. **Task close finalization:** closing active Homework/Blitz auto-finalizes in-progress attempts and records the close-driven finalization reason.
9. **Result closure:** only a terminal calculated or definitive Not completed Student+Topic result can be closed; release remains separate.
10. **Homework tie:** an exact highest-score tie selects the earliest tied attempt reference.
