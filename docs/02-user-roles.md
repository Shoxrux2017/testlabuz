# TestLabUz — User Roles

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

## 1. Platform Owner / Super Admin

The **Platform Owner / Super Admin** is the highest-level role in **TestLabUz**.

This role manages the whole platform, not just one educational institution. The Platform Owner / Super Admin is responsible for controlling institutions, monitoring platform activity, managing global platform settings, and making sure the system works correctly for all institutions.

The Super Admin can create and manage educational institutions inside the platform. For example, schools, colleges, lyceums, universities, institutes, learning centers, and other education organizations can be added and controlled by this role.

The Super Admin can manage institution accounts, view institution status, activate or deactivate institutions, and review general usage information. However, the Super Admin should not normally interfere with daily teaching activities unless support, security, or system management requires it.

The Super Admin can access platform-level information, such as:

- List of all institutions
- Institution status
- Number of users in each institution
- Basic platform statistics
- Global platform settings
- Support and issue reports
- Institution activity overview

The Super Admin can also manage or assist Institution Admins when needed. For example, if an Institution Admin loses access, needs help with platform-level access, or has a system issue, the Super Admin can support them.

The Super Admin must not normally change:

- Student answers or submissions
- Teacher-created homework or blitz content
- Homework or blitz scores
- Final topic results
- Understanding categories
- Result-release decisions for normal classroom work

Institution-level educational data remains under the institution's normal role and permission rules.

In the MVP version, the Super Admin role should focus on basic platform management. Advanced tools such as billing, subscriptions, platform analytics, license management, impersonation, and advanced audit reports can be added in later versions.

The main purpose of the Platform Owner / Super Admin role is to manage the **TestLabUz** platform as a whole and keep all institutions organized, separate, and controlled.

## 2. Institution Admin

The **Institution Admin** is the main management role inside one educational institution.

This role does not manage the whole **TestLabUz** platform. Instead, the Institution Admin manages only their own school, college, lyceum, university, institute, learning center, or other educational organization.

The Institution Admin is responsible for setting up and organizing the institution inside the system. This includes managing users, groups, relationships, institution-level learning settings, and basic progress information.

The Institution Admin can manage:

- Teachers
- Students
- Parents
- Classes or groups
- Student-group assignments
- Teacher-group assignments
- Parent-student relationships
- User access and account status
- Institution settings
- Acceptable Homework–Blitz score-difference threshold
- Understanding-category score ranges
- Blitz timer-start mode
- Student result-release mode
- Parent result-visibility mode
- Institution timezone
- Institution upload limits within platform maximums
- Basic reports and progress overview

The Institution Admin can create Teacher, Student, and Parent accounts. They can also connect Students to Parents, assign Students to groups, and assign Teachers to the groups they teach.

### Institution learning settings

The Institution Admin configures institution-wide rules that Teachers and Students use.

The Institution Admin can define the acceptable Homework–Blitz score-difference threshold used when the system decides whether two official scores are close or inconsistent.

The Institution Admin can configure numeric score ranges for these understanding categories:

- Understood well
- Partially understood
- Needs revision
- Needs teacher support

The **Not completed** category is not a numeric range. It is used when required work can no longer validly be completed.

The Institution Admin chooses one Blitz timer-start mode for the institution:

- **Synchronized start** — the timer starts for all assigned Students when the Teacher activates the Blitz.
- **Individual start** — the Blitz becomes available after Teacher activation, but each Student receives the full duration starting when that Student starts the attempt.

The Institution Admin chooses the Student result-release mode:

- **Automatic** — the result becomes visible to the Student after the result is fully calculated.
- **Manual Teacher release** — the result can be calculated but remains hidden until the Teacher releases it.

The Institution Admin chooses the Parent result-visibility mode:

- **With Student** — Parent visibility starts automatically after the Student result is released.
- **Manual Teacher release** — the Parent result remains hidden until the Teacher releases it after the Student result is available.
- **Hidden** — the Parent does not receive the result.

A Parent must never receive a result before the Student result has been released.

The Institution Admin configures the institution timezone using an IANA timezone identifier, such as `Asia/Tashkent`. Educational dates and deadlines are interpreted and displayed using the institution timezone, while authoritative timestamps are handled by the server.

The platform upload limits are:

- Learning materials: maximum **25 MB per file**
- Student file-based submissions: maximum **15 MB per file**

The Institution Admin may configure lower limits for the institution, but cannot configure values above these platform maximums.

### Attempt-rule boundary

The Institution Admin does **not** configure arbitrary Homework or Blitz attempt counts in the MVP.

The approved attempt rules are fixed:

- Homework: exactly **3 normal attempts**
- Blitz: exactly **1 normal attempt**
- One additional Blitz attempt may be granted to one Student by an authorized Teacher for a valid technical or other approved reason

This keeps the core learning-check process consistent across institutions.

The Institution Admin can view general progress information for the institution. For example, they may see which groups are active, how Students are performing, and which topics or groups may need attention.

However, the Institution Admin should not normally complete tasks for Students, change Student answers, manually score Teacher-owned work, or override calculated final results. Their main responsibility is management and organization, not daily teaching.

The Institution Admin can only access data that belongs to their own institution. They cannot view or manage another institution's users, groups, topics, assignments, results, or settings.

In the MVP version, the Institution Admin role should focus on managing institution structure, users, relationships, approved institution settings, and basic progress overview.

The main purpose of the Institution Admin role is to keep the educational institution organized inside **TestLabUz** and make sure Teachers, Students, and Parents have the correct access and institution-level rules.

## 3. Teacher Role

The **Teacher** is the main educational role in **TestLabUz**.

Teachers are responsible for creating learning content, assigning tasks, conducting Blitz verification, checking Student work, and reviewing how well Students understand a specific topic.

A Teacher works inside one educational institution and can only manage the groups, Students, topics, tasks, submissions, and results within the Teacher's assigned scope.

The Teacher can create and manage:

- Topics
- Learning materials
- Homework assignments
- Blitz tasks
- Questions
- Question points and scoring rules
- Task instructions
- Homework deadlines
- Blitz duration
- Official result-bearing Homework and Blitz designation
- Manual answer checking
- Student-specific Blitz attempt exceptions
- Teacher feedback
- Result release when institution policy requires Teacher action
- Progress and results for assigned Students

### Topics and official task pair

A Topic may contain multiple Homework assignments and multiple Blitz tasks.

For the MVP final Topic result, exactly:

- **one Homework assignment**, and
- **one Blitz task**

must be designated as the official result-bearing pair.

Only this official pair is used for the Homework–Blitz comparison, final Topic score, and understanding category. Both official tasks must use whole-group assignment. Practice tasks may use whole-group or selected-Student assignment, but selected-Student tasks cannot become result-bearing.

The official pair may be assembled progressively. The Teacher may designate the whole-group official Homework before the official Blitz exists. The Topic-level result-pair row keeps the Homework side while the Blitz side remains empty until the Blitz stage. When the first official task becomes active, its persisted whole-group recipient snapshot establishes the common official cohort. The later official task must reuse that cohort. Once Student attempt activity locks the official Homework/cohort, the Homework side cannot be replaced; the later addition of the previously missing official Blitz completes the same pair and is not a replacement.

### Learning materials

The Teacher can upload learning materials related to a Topic.

The supported MVP formats are:

- PDF
- DOCX
- PPT
- PPTX

The platform maximum learning-material file size is **25 MB per file**. The effective institution limit may be lower if configured by the Institution Admin.

### Homework

The Teacher can create Homework assignments using all nine supported assignment types:

1. Single-choice
2. Multiple-choice
3. True / false
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching
8. Ordering
9. Fill-in-the-blank

Each Student receives exactly **3 normal attempts** for Homework.

The Teacher does not configure a different Homework attempt count in the MVP.

The official Homework score is the **highest valid completed score** among the Student's three normal attempts.

Example:

```text
Attempt 1: 60
Attempt 2: 82
Attempt 3: 75

Official Homework score: 82
```

If required manual checking is still unfinished for a potentially official attempt, the Homework score is not yet final.

### Blitz

The Teacher manually creates the Blitz task and chooses its questions and total duration.

The Blitz should normally be short and focused and is intended for use during approximately the first 5–10 minutes of the next lesson.

The Teacher configures the duration of each Blitz. The institution's timer-start mode determines when that duration begins.

The Teacher activates the Blitz during class.

Under **synchronized start**:

- Teacher activation starts the timer for all assigned Students.
- Students who open later receive only the remaining time.

Under **individual start**:

- Teacher activation makes the Blitz available.
- Each Student's timer starts when that Student starts the Blitz.
- Each Student receives the full configured duration.

The Teacher does not control the authoritative clock. Server time determines start, remaining time, and timeout.

### Blitz attempt exception

Each Student normally has exactly **1 Blitz attempt**.

If a Student cannot properly complete that attempt because of a valid technical problem or another approved reason, the Teacher may grant **one additional Blitz attempt to that specific Student**.

The Teacher must provide a reason for granting the exception.

The original interrupted or invalid attempt remains in history and is excluded from official scoring according to the approved exception.

A Student can therefore have at most:

- 1 normal Blitz attempt, plus
- 1 approved exception attempt

The additional opportunity is Student-specific and does not increase the attempt count for the whole class.

### Checking and scoring

Some question types are checked automatically. Others require Teacher review.

The approved scoring behavior includes:

- Single-choice: all-or-nothing
- True / false: all-or-nothing
- Multiple-choice: Student selections are capped at the number of correct options; partial credit is based only on correctly selected options / total correct options
- Matching: partial credit per correctly matched pair
- Ordering: partial credit per correctly positioned item
- Fill-in-the-blank: partial credit per correctly completed blank
- Short written answer: automatic when accepted-answer rules allow; otherwise Teacher review
- Open written answer: Teacher assigns points
- File-based assignment: Teacher assigns points

The Teacher may score and comment on answers requiring judgment, but must not rewrite the Student's submitted answer.

The Teacher may correct an underlying manual score before the final result is closed. The system must then recalculate the Topic result.

The Teacher must not directly override the final Topic score outside the approved Homework–Blitz formula.

### Result review and release

After official Homework and Blitz scores are available, the system calculates the final Topic result.

The Teacher can review:

- Official Homework score
- Official Blitz score
- Absolute score difference
- Consistency or inconsistency
- Final score
- Understanding category
- Completion/review status
- Student feedback where applicable

Homework/Blitz comparison and final-score calculation use unrounded values. User-facing scores are displayed with **one decimal place**. Understanding-category assignment uses the derived integer `category_score` where `.0`–`.5` rounds down and `>.5` rounds up.

Result calculation and result visibility are separate.

If the institution uses **automatic Student release**, the Student receives the result automatically after calculation is complete.

If the institution uses **manual Teacher release**, the Teacher releases the calculated result to the Student.

For Parent visibility:

- `with_student` follows Student release,
- `manual_teacher` requires a separate Teacher release after Student release,
- `hidden` keeps the result unavailable to Parents.

The Teacher should use the results to identify:

- Students who understood the Topic well
- Students who partially understood it
- Students who need revision
- Students who need direct Teacher support
- Students who did not complete required work

Teachers should not manage institution-wide settings, institution accounts, unrelated groups, or another institution's data.

In the MVP version, the Teacher role should focus on the complete learning-check process: creating Topics and materials, creating Homework, conducting Blitz verification, checking Student work, reviewing results, and releasing results where required.

The main purpose of the Teacher role is to give Teachers a reliable way to measure real understanding rather than relying only on Homework completion.

## 4. Student Role

The **Student** is the main learning user in **TestLabUz**.

Students use the system to study learning materials, complete Homework assignments, answer Blitz tasks, and view their own learning results when those results are released.

A Student belongs to one educational institution and may be connected to one or more classes or groups inside that institution.

The Student can access, when assigned and allowed:

- Assigned Topics
- Learning materials
- Homework assignments
- Blitz tasks
- Task instructions
- Homework deadline
- Attempt information
- Blitz duration and remaining time
- Own submissions
- Own released scores
- Own released understanding categories
- Own learning progress

### Homework attempts

Each Student receives exactly **3 normal attempts** for an assigned Homework. If an authoritative Homework deadline arrives while one of the Student's Attempts is still `in_progress`, the backend automatically finalizes that Attempt from the saved answers, scores unanswered components as zero, and prevents any further attempts or edits after the deadline. A Student who never started does not receive a fabricated Attempt.

The Student should be able to see:

- Current attempt number
- Number of attempts already used
- Number of attempts remaining

Each attempt is stored separately.

The Student cannot edit a submitted attempt.

The official Homework score is the highest valid completed score from the three attempts.

### Blitz access and timing

Each Student normally receives exactly **1 Blitz attempt**.

The Student may access the Blitz only after the Teacher activates it.

In synchronized-start institutions, the timer begins when the Teacher activates the Blitz. A Student who enters later sees only the remaining time.

In individual-start institutions, the timer begins when that Student starts the Blitz and the Student receives the full Teacher-configured duration.

The Student must clearly see the remaining time.

When the Blitz timer reaches zero:

- The system stops accepting changes.
- The current saved answers are automatically finalized.
- Answers saved before the deadline are evaluated normally.
- Unanswered questions receive zero points.
- Answers requiring Teacher judgment remain waiting for Teacher review.
- Writes received after the authoritative deadline are rejected.

Changing the device clock or device timezone must not give the Student additional time.

### Blitz technical exception

If a valid technical or other approved problem prevented proper completion of the normal Blitz attempt, the Teacher may grant one additional attempt.

The Student cannot grant this exception to themselves.

The Student should be able to see when an additional approved attempt is available.

The original invalid/interrupted attempt remains in history.

### File-based answers

For file-based assignment answers, the platform maximum is **15 MB per file**.

The effective institution limit may be lower.

An oversized, unsupported, or failed upload is not a valid submitted answer.

### Results

After Homework and Blitz work is complete and any required Teacher review is finished, the system may calculate the Student's Topic result.

The Student sees that result only according to the institution's release policy.

A result can be fully calculated while still hidden from the Student.

When released, the Student may see:

- Official Homework score
- Official Blitz score
- Final Topic score
- Consistency information where allowed
- Understanding category
- Completion status
- Teacher feedback where available

Scores are displayed with one decimal place.

Students must not be able to:

- Change submitted answers after submission or timeout
- View another Student's answers, scores, files, or private progress
- Create official Topics or learning materials
- Create Homework or Blitz tasks
- Activate Blitz tasks
- Grant additional attempts
- Check answers
- Change scores or categories
- Release results
- Manage users, groups, or institution settings

In the MVP version, the Student role should focus on the core learning flow: studying materials, completing Homework, answering Blitz tasks, and viewing released personal results.

The main purpose of the Student role is to support independent learning and provide a fair way to demonstrate understanding through both home and in-class work.

## 5. Parent Role

The **Parent** role is used to monitor a child's learning progress in **TestLabUz**.

Parents do not create learning content, complete assignments, manage users, or change educational data. Their main purpose is to view permitted information about their child's progress.

A Parent belongs to one educational institution and is explicitly connected to one or more Students inside that institution.

A Parent may view, when institution result-visibility rules allow:

- Child's assigned Topic progress
- Homework completion status
- Blitz completion status
- Released Homework and Blitz scores
- Released final Topic score
- Released understanding category
- General learning progress
- Topics where the child may need more support

Parent result visibility follows the Institution Admin's configured mode:

- **With Student** — the Parent receives access automatically after the Student result is released.
- **Manual Teacher release** — the Parent receives access only after the Student result is released and the Teacher separately releases it to the Parent.
- **Hidden** — the Parent does not receive the Topic result.

A Parent must never receive the result before it has been released to the Student.

A calculated result that is not visible to a Parent is not incomplete; it is simply not released to that Parent.

Parents should not be able to:

- View unrelated Students
- View other Parents' information
- Complete Homework for the Student
- Answer Blitz tasks
- Upload Student submissions
- Change Student answers
- Change scores or categories
- Release results
- Grant additional attempts
- Manage users, groups, Topics, tasks, or institution settings

In the MVP version, Parents use the mobile version of the application.

The main purpose of the Parent role is to give Parents a convenient and controlled way to understand their child's learning progress and identify when additional support may be needed.

## 6. Role Relationships

In **TestLabUz**, each role is connected to other roles through the educational institution structure.

Because the platform supports many institutions from the beginning, every institution-level user, group, Topic, task, attempt, submission, score, and result must belong to the correct institution scope.

The **Platform Owner / Super Admin** is connected to the whole platform. This role manages institutions at platform level but does not normally participate in one institution's daily learning workflow.

The **Institution Admin** belongs to one institution and manages the internal structure and approved institution-wide settings for that institution.

The **Teacher** belongs to one institution and is assigned to specific groups. A Teacher may create and manage learning content and results only inside the assigned scope.

The **Student** belongs to one institution and may belong to one or more groups. Students receive Topics and tasks only through allowed assignments.

The **Parent** belongs to one institution and must have an explicit Parent–Student relationship before viewing that Student's permitted progress.

The main role relationships are:

- One platform can have many institutions.
- One institution can have many Institution Admins, Teachers, Students, and Parents.
- One institution can have many groups.
- One group can have many Students.
- One Teacher can be assigned to many groups.
- One group can have one or more Teachers.
- One Student may belong to one or more groups in the same institution.
- One group can have many Topics.
- One Topic can have many learning materials.
- One Topic can have multiple Homework assignments.
- One Topic can have multiple Blitz tasks.
- Exactly one whole-group Homework and one whole-group Blitz are designated as the official result-bearing pair; selected-Student tasks are practice-only.
- One Student can have many task attempts.
- One Parent can be connected to one or more Students.
- One Student can have one or more Parents.

Topics, tasks, official task pairs, attempts, submissions, and results must always remain connected to the correct institution, group, Teacher, and Student context.

Knowing a record identifier, file address, Student identifier, or task identifier does not grant access by itself.

The main purpose of defining role relationships is to make sure every user sees only the information they are allowed to see and every action happens inside the correct institution and learning context.

## 7. Access and Permissions Rules

In **TestLabUz**, every user should have access only to information and actions that belong to their role, institution, group, assignment, ownership, and relationship scope.

The main access rule is:

> **Each user can only access data and perform actions that belong to their authorized scope.**

### Platform Owner / Super Admin

The Super Admin can:

- Create and manage institutions
- Activate or deactivate institutions
- View platform-level information
- Manage platform settings
- Support Institution Admin access when necessary

The Super Admin should not normally change daily educational data such as Student answers, Teacher-created tasks, or calculated classroom results.

### Institution Admin

The Institution Admin can manage only their own institution.

The Institution Admin can configure:

- Acceptable Homework–Blitz difference threshold
- Understanding-category ranges
- Blitz timer-start mode
- Student result-release mode
- Parent result-visibility mode
- Institution timezone
- Lower institution upload limits

The Institution Admin cannot configure arbitrary Homework or Blitz attempt counts in the approved MVP.

### Teacher

The Teacher can manage only assigned groups, Topics, tasks, submissions, and results.

The Teacher can:

- Create and edit allowed learning content
- Designate each official task before its own attempts begin; the official Homework may be designated before the official Blitz exists
- Set Homework deadlines
- Set Blitz duration
- Activate Blitz tasks
- Grant one Student-specific additional Blitz attempt for a valid reason
- Check manual answers
- Correct underlying manual scoring before result closure
- Release Student or Parent results when institution policy requires Teacher release

The Teacher cannot directly override the final Topic calculation formula.

### Student

The Student can access only assigned learning content, own attempts, own submissions, and own released results.

The Student cannot:

- Change fixed attempt rules
- Grant themselves an additional Blitz attempt
- Change authoritative timers
- View another Student's private data
- Change scoring or results

### Parent

The Parent can access only permitted progress for explicitly connected Students.

Parent access is read-only.

### Protected actions

Important actions must be protected by server-side permissions and scope checks, including:

- Creating, editing, activating, or deactivating users
- Creating or editing groups
- Assigning Teachers and Students to groups
- Connecting Parents to Students
- Changing institution learning settings
- Creating and editing Topics
- Uploading or removing learning materials
- Creating and editing Homework
- Creating and editing Blitz tasks
- Designating the official result-bearing pair
- Activating or closing Blitz tasks
- Starting and submitting attempts
- Granting a Blitz attempt exception
- Checking manual answers
- Assigning manual scores and feedback
- Recalculating a result after an allowed underlying correction
- Releasing Student results
- Releasing Parent results
- Viewing reports
- Activating or deactivating institutions

The system must clearly separate **view access** and **edit access**.

For example:

- A Parent may view an allowed released result but cannot edit it.
- A Student may view their own released result but cannot change it.
- A Teacher may review assigned Student results but cannot manage institution-wide settings.
- An Institution Admin may configure institution rules but cannot rewrite Student answers.

If a user tries to access information outside their permission scope, the system must block the action.

The same security rules apply on desktop and mobile.

The main purpose of access and permissions rules is to protect Student privacy, institution data, assessment integrity, and the approved educational workflow.

## 8. Platform Access by Device

In **TestLabUz**, different roles use the platform from different devices according to their responsibilities.

The approved MVP access model is:

- Platform Owner / Super Admin: **desktop**
- Institution Admin: **desktop**
- Teacher: **desktop and mobile**
- Student: **desktop and mobile**
- Parent: **mobile**

### Teacher

Teachers should have both desktop and mobile access.

Desktop is suitable for:

- Creating Topics
- Uploading learning materials
- Creating Homework
- Creating Blitz tasks
- Building questions
- Checking written/file answers
- Reviewing detailed results
- Managing result release

Mobile is suitable for quick classroom actions such as:

- Viewing assigned groups
- Activating a Blitz
- Monitoring Blitz participation
- Reviewing basic Student progress
- Granting a Student-specific Blitz exception when necessary
- Releasing results when appropriate

### Student

Students should have both desktop and mobile access.

Students may use desktop for:

- Studying materials
- Completing larger Homework tasks
- Uploading files
- Writing longer answers

Students may use mobile for:

- Studying materials
- Completing simple Homework
- Answering tests
- Participating in Blitz tasks

The same authoritative attempt, timer, deadline, and permission rules apply on both devices.

### Platform Owner / Super Admin and Institution Admin

Admin roles use desktop in the MVP.

The Institution Admin interface should support user/group management, institution settings, category ranges, timer-start mode, release policies, timezone, upload limits, and reports.

### Parent

Parents use mobile in the MVP.

The Parent interface should focus on simple read-only progress monitoring and show results only when the configured visibility rules allow them.

Device choice must never expand a user's permissions.

The main purpose of defining platform access by device is to keep each interface practical and aligned with real role responsibilities.

## 9. User Roles Summary

In **TestLabUz**, the MVP includes five roles:

1. **Platform Owner / Super Admin**
2. **Institution Admin**
3. **Teacher**
4. **Student**
5. **Parent**

The **Platform Owner / Super Admin** manages the whole platform and institution lifecycle at platform level.

The **Institution Admin** manages one institution, its users, groups, relationships, approved learning settings, and basic progress overview.

The **Teacher** manages the educational process for assigned groups. Teachers create Topics and tasks, set Homework deadlines and Blitz duration, designate the official Homework/Blitz pair, check manual answers, grant one allowed Student-specific Blitz exception, review results, and release results where institution policy requires it.

The **Student** studies materials, completes Homework using three normal attempts, completes normally one Blitz attempt, may use one additional Teacher-approved Blitz attempt when validly granted, and views personal results after release.

The **Parent** monitors connected children's progress according to institution Parent-visibility rules and cannot change educational data.

All roles must remain inside the correct institution and relationship scope.

The approved device model is:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

The main purpose of the role system is to give every user one clear responsibility, one clear access boundary, and the tools required for that responsibility.

## 10. MVP Role Scope and Future Roles

The MVP role system should stay focused on the core learning-check workflow.

The five approved MVP roles are:

1. **Platform Owner / Super Admin**
2. **Institution Admin**
3. **Teacher**
4. **Student**
5. **Parent**

These roles cover:

- Platform management
- Institution management
- Teaching and assessment
- Student learning
- Parent progress monitoring

No additional specialized role is required for the initial MVP.

Future versions may include roles such as:

- **Institution Owner / Director** — views high-level institution performance and reports
- **Department Manager** — manages Teachers, groups, or subjects inside a department
- **Group / Class Curator** — monitors one class or group more closely
- **Assistant Teacher** — helps a Teacher manage materials, tasks, or checking
- **Content Moderator** — reviews uploaded materials and task content
- **Platform Support Agent** — supports institutions
- **Finance / Billing Manager** — manages future subscriptions or licensing
- **Report Viewer** — read-only reporting role
- **Guest / Observer** — limited temporary read-only access

These future roles are outside the MVP unless separately approved later.

The main rule for the MVP is:

> **Each user must have one clear role, one clearly defined scope, and only the tools needed for that role.**
## Post-Audit Role Clarifications

- **Institution Admin:** educational-policy settings have no silent initial default. The Admin must explicitly configure threshold, complete integer category ranges, Blitz timer-start mode, Student release mode, and Parent visibility mode before dependent learning operations can use them.
- **Administrator-created users:** Institution Admins, Teachers, Students, and Parents must change their initial password at first login; normal application access is blocked until they do so.
- **Teacher:** may create practice Homework/Blitz for selected Students, but official grading tasks must be whole-group and share one snapshotted Topic cohort. The Teacher may close a Student Topic Result only after that Student reaches a terminal calculated or definitive Not completed state.
- **Student:** for Multiple-choice, may never select more options than the server-provided `max_selections`; no correct-answer identity is exposed.
- **Teacher/Student task closure:** closing active Homework/Blitz auto-finalizes currently in-progress Student attempts from saved answers; Students who never started get no fabricated Attempt.
