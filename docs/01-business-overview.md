# TestLabUz — Business Overview

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

## 1. Project Name

**TestLabUz**

## 2. Business Idea Summary

**TestLabUz** is an educational platform for schools, colleges, lyceums, universities, institutes, learning centers, and other educational institutions. The application helps teachers understand how well students have actually mastered a specific topic.

The learning process is centered on a **Topic**. A teacher creates a topic, uploads learning materials in PDF, DOCX, PPT, or PPTX format, and creates homework connected to that topic. Students study the materials and complete the homework at home.

Homework alone is not treated as sufficient proof of understanding because a student may receive outside help. During approximately the first 5–10 minutes of the next lesson, the teacher therefore gives a short in-class **Blitz task** connected to the same topic.

For the official Topic result, exactly one **whole-group Homework** and exactly one **whole-group Blitz** are designated as the result-bearing pair. A Topic may contain additional Homework or Blitz tasks for practice; those supplementary tasks may target the whole group or selected Students but do not affect the final Topic result.

Homework has exactly **three normal attempts** in the MVP. The highest valid completed Homework score becomes the official Homework score. Blitz normally has exactly **one attempt**. If a valid technical or other exceptional problem prevents a student from completing the Blitz properly, the Teacher may grant that specific student **one additional Blitz attempt** with a recorded reason. The affected attempt remains in history and is excluded from official scoring when the exception is approved.

The system compares the official Homework score and official Blitz score on the same 0–100 scale. Each institution defines an acceptable score-difference threshold. If the difference is within that threshold, the final score is the arithmetic average of Homework and Blitz. If the difference is larger than the threshold, the Blitz score becomes the final score. A large difference is treated as an inconsistency that needs educational interpretation, not as automatic proof of cheating.

The final score is converted into a clear understanding category so teachers can quickly identify students who understood the topic well, partially understood it, need revision, need teacher support, or did not complete the required work.

TestLabUz is designed as a multi-institution platform from the beginning. Each institution has its own users, groups, topics, tasks, settings, submissions, results, and reports, and data from one institution must remain separated from every other institution.

Future versions may include AI features, audio/video learning, advanced analytics, communication tools, integrations, and monetization. The MVP focuses on proving the core Homework–Blitz learning-check model in a simple and practical way.

## 3. Problem Statement

In many educational institutions, teachers cannot always clearly determine how well students have mastered a specific topic.

Students may receive learning materials and Homework after a lesson, but because Homework is completed outside the classroom, the Teacher cannot always know whether the student worked independently. A student may use external tools, ask another person for help, copy an answer, or complete the task without truly understanding the topic.

Because of this, a Homework score alone may not accurately represent the Student's real level of understanding. A Student can receive a high score at home but struggle to explain or apply the same knowledge during class.

Teachers therefore need a simple and consistent way to compare home performance with a short in-class verification task. TestLabUz uses a Blitz task for this purpose.

The platform must also handle practical classroom situations fairly. Homework needs enough opportunities for normal learning and correction, while Blitz should remain a controlled in-class verification. For that reason, Homework has three normal attempts and uses the highest valid completed score, while Blitz normally has one attempt with at most one Teacher-approved Student-specific exception for a valid technical or other exceptional reason.

The main problem **TestLabUz** solves is the lack of a reliable, practical, and transparent way to estimate a Student's real understanding of a topic by comparing Homework performance with a short, time-controlled in-class Blitz result.

## 4. Proposed Solution

**TestLabUz** solves this problem by creating a structured topic-based learning and verification process.

The Teacher creates a Topic and uploads learning materials in PDF, DOCX, PPT, or PPTX format. Students use those materials to review the lesson independently. The Teacher then creates Homework connected to the same Topic.

For the official result, the Topic uses one designated whole-group Homework and one designated whole-group Blitz as its result-bearing pair. Practice tasks may target the whole group or selected Students, but selected-Student tasks cannot become result-bearing. When the first official task becomes active, the system snapshots the current eligible Students in the Topic group and uses that same cohort for both official tasks. Once Student attempt activity begins, the official pair and cohort are locked.

Each Student receives three normal Homework attempts. The system keeps every attempt and uses the highest valid completed Homework score as the official Homework score.

During approximately the first 5–10 minutes of the next lesson, the Teacher activates the designated Blitz. The Teacher defines the Blitz duration. The institution chooses one of two timer-start modes:

- **Synchronized start** — the timer starts for all assigned Students when the Teacher activates the Blitz.
- **Individual start** — the Blitz becomes available after Teacher activation, but each Student receives the full duration starting when that Student starts the attempt.

Blitz normally permits one attempt. For a valid technical or other exceptional reason, the Teacher may grant one additional attempt to one affected Student and must record the reason. The original affected attempt remains in history for traceability.

When Blitz time expires, the system automatically finalizes the saved attempt. Answers saved before the deadline are evaluated; unanswered questions receive zero points. Answers requiring Teacher judgment remain waiting for manual review rather than being treated as wrong merely because they need manual checking.

After all required automatic and manual checking is complete, the system compares the official Homework score and official Blitz score. Let `H` be Homework, `B` be Blitz, `D = |H - B|`, and `T` be the institution's acceptable difference threshold:

- If `D <= T`, the final score is `(H + B) / 2`.
- If `D > T`, the final score is `B`.

Homework/Blitz comparison and final-score calculation use unrounded score values. User-facing scores are displayed rounded to one decimal place. For category assignment only, the final internal score is converted to an integer `category_score`: fractional parts `.0` through `.5` round down, while values greater than `.5` round up.

Finally, TestLabUz assigns one of the approved understanding categories and makes the result available according to the institution's result-release settings. Result calculation and result visibility remain separate: a result can be fully calculated while still not visible to a Student or Parent.

## 5. Target Institutions

**TestLabUz** is designed for different types of educational institutions from the beginning.

The system can be used by:

- Schools
- Colleges
- Lyceums
- Universities
- Institutes
- Learning centers
- Training centers
- Private education organizations
- Other institutions that teach students and need to monitor learning results

The application should not be limited to only one type of institution. Different institutions may have different structures, subjects, groups, teachers, students, and assessment methods, so the system should be flexible enough to support them.

Each institution should be able to manage its own users, classes or groups, topics, learning materials, assignments, blitz tasks, and reports separately from other institutions.

This means **TestLabUz** will be built as a multi-institution platform. Many institutions can use the same system, but each institution’s data should remain separate and private.

In the MVP version, the system will support the basic needs of these institutions: creating topics, uploading materials, assigning tasks, giving blitz tasks, and viewing student understanding results. Future versions can add more advanced features for different institution types.

## 6. User Groups

**TestLabUz** supports five approved MVP roles:

1. **Platform Owner / Super Admin**
2. **Institution Admin**
3. **Teacher**
4. **Student**
5. **Parent**

Each role has its own permissions and access scope.

The **Platform Owner / Super Admin** manages the TestLabUz platform itself. This role can create and manage institutions, activate or deactivate institutions, monitor basic platform-level information, and support institution access. The Super Admin does not normally manage daily classroom content, Student answers, or educational scores.

The **Institution Admin** manages one educational institution. This role manages Teachers, Students, Parents, groups, relationships, institution settings, basic reports, understanding-category ranges, the acceptable Homework–Blitz score-difference threshold, the Blitz timer-start mode, result-release rules, institution timezone, and allowed upload limits within platform maximums.

The **Teacher** manages the learning process for assigned groups and Students. Teachers create Topics, upload learning materials, create Homework and Blitz tasks, select the official result-bearing Homework and Blitz pair, configure each Blitz duration, activate Blitz tasks, review manual answers, give feedback, and review Topic results. Teachers may also grant one additional Blitz attempt to a specific Student when a valid technical or other exceptional reason exists.

The **Student** studies assigned learning materials, completes assigned Homework, participates in active Blitz tasks, and views their own released results and progress. Students cannot see another Student's answers or results.

The **Parent** has read-only access to permitted progress information for explicitly connected children. Parent result visibility follows the institution's configured policy and can never bypass the Student result-release state.

Device access in the MVP is:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

Every user must remain inside the correct institution, role, group, task, ownership, and relationship scope.

## 7. Core Learning Process

The core learning process in **TestLabUz** is built around one main goal: to check how well a Student really understands a specific Topic.

1. The Teacher explains the Topic during the lesson.
2. The Teacher creates the Topic in TestLabUz.
3. The Teacher uploads learning materials in PDF, DOCX, PPT, or PPTX format.
4. The Teacher creates Homework connected to the Topic.
5. The Student studies the materials independently.
6. The Student completes Homework using up to three normal attempts.
7. The system keeps all Homework attempts and selects the highest valid completed score as the official Homework score after required checking is complete.
8. During approximately the first 5–10 minutes of the next lesson, the Teacher activates the designated Blitz for the same Topic.
9. The Blitz timer follows the institution's configured synchronized-start or individual-start mode and the duration chosen by the Teacher.
10. The Student completes the Blitz in class. Normally there is one attempt; one additional Student-specific attempt may be granted by the Teacher only for an approved valid exception.
11. If Blitz time expires, the system automatically finalizes saved work, scores answered items according to their checking rules, and gives zero for unanswered items.
12. Required manual review is completed before the official Homework or Blitz score becomes final.
13. The system compares the official Homework and Blitz scores using the institution's acceptable-difference threshold.
14. If the scores are close, the system uses their arithmetic average. If the difference is too large, the system uses the Blitz score.
15. The system assigns the appropriate understanding category.
16. The calculated result becomes visible to the Student and Parent according to the institution's configured release policies.

A Topic may contain supplementary Homework or Blitz tasks, but exactly one Homework and one Blitz form the official pair used for the Topic result.

This process helps Teachers make better educational decisions without relying only on work completed at home.

## 8. Learning Materials

In **TestLabUz**, learning materials are resources uploaded by Teachers for Students to study independently after a lesson.

The MVP supports:

- PDF
- DOCX
- PPT
- PPTX

Each learning material must belong to a specific Topic and therefore remain inside the correct institution, Teacher, group, and Student access scope.

The platform maximum for one Teacher learning-material file is **25 MB**. An Institution Admin may configure a lower institution limit, but an institution cannot configure a limit higher than the platform maximum.

Students should be able to open or download materials for Topics assigned to them. Material files must not be exposed through public links that bypass platform permissions.

Teachers manage the learning materials for their Topics. Institution Admins may view material activity for management or support but should not normally replace the Teacher's content-management role.

The main purpose of learning materials is to support independent learning, revision, and preparation for Homework and the next in-class Blitz.

Future versions may support audio, video, interactive content, external links, and AI-generated study resources. These are outside the MVP.

## 9. Assignment Types

In **TestLabUz**, Homework and Blitz tasks may use the same nine MVP assignment types:

1. **Single-choice test**  
   The Student chooses one answer from several options. Automatic scoring is all-or-nothing.

2. **Multiple-choice test**  
   The Student may select multiple options. Partial credit is based on correctly classifying each option as selected or not selected, so incorrect selections reduce the earned proportion and selecting every option does not guarantee full credit.

3. **True / false question**  
   The Student decides whether a statement is true or false. Automatic scoring is all-or-nothing.

4. **Short written answer**  
   The Student gives a short text response. It may be automatically checked against Teacher-defined accepted answers or manually reviewed when judgment is required.

5. **Open written answer**  
   The Student writes a longer explanation. The Teacher reviews the answer manually and assigns points within the allowed maximum.

6. **File-based assignment**  
   The Student uploads a file as an answer. MVP answer-file formats are PDF, DOCX, PPT, and PPTX. The platform maximum is **15 MB per Student answer file**, and the institution may configure a lower limit. File-based answers require Teacher review.

7. **Matching task**  
   The Student matches items. Partial credit is awarded per correctly matched pair.

8. **Ordering task**  
   The Student places items in the correct order. Partial credit is awarded per item in the correct position.

9. **Fill-in-the-blank task**  
   The Student completes one or more blanks. Partial credit is awarded per correctly completed blank.

Automatically checkable questions are scored by the system. Questions requiring educational judgment remain **Waiting for teacher review** until the Teacher checks them. A task's official score is not complete until all required manual review is finished.

The attempt rule is determined by whether the task is Homework or Blitz, not by assignment type:

- Homework: exactly three normal attempts; the highest valid completed score is official.
- Blitz: exactly one normal attempt, plus at most one Teacher-approved Student-specific exception attempt for a valid reason.

Negative marking is not part of the MVP unless explicitly added in a future version.

## 10. Blitz Task Concept

In **TestLabUz**, the Blitz is a short in-class assessment used to verify a Student's real understanding of the same Topic studied through learning materials and Homework.

Blitz tasks are created manually by Teachers in the MVP. AI-generated Blitz tasks are future scope.

The Teacher chooses the Blitz questions, points, instructions, recipients, and **whole-Blitz duration**. The MVP does not use a separate timer for each question.

Each institution chooses one Blitz timer-start mode:

- **Synchronized start** — the Teacher's activation starts the timer for all assigned Students. A Student who opens the Blitz late has only the remaining shared time.
- **Individual start** — Teacher activation makes the Blitz available, and each Student receives the full configured duration beginning when that Student starts the attempt.

Server time is authoritative. A Student cannot gain additional time by changing the device clock or timezone.

A Student normally receives **one Blitz attempt**. If a valid technical or other exceptional problem prevents proper completion, the Teacher may grant that Student **one additional attempt** and must record a reason. The affected original attempt remains in history and, once the exception is approved, is excluded from the official Blitz score.

When the timer reaches zero:

- the Student can no longer change answers;
- the system automatically finalizes the saved attempt;
- answers saved before the deadline are evaluated normally;
- unanswered questions receive zero points;
- answers requiring manual Teacher review remain waiting for review;
- the official Blitz score becomes available only after all required review is complete.

The designated Blitz score is compared with the designated Homework score for the same Topic. A large difference indicates inconsistent home and in-class performance, but the platform must not automatically accuse the Student of cheating.

The purpose of Blitz is not to create unnecessary pressure. Its purpose is to provide a short, controlled, and more reliable in-class verification of Topic understanding.

## 11. Understanding Assessment Categories

TestLabUz shows Topic results using both a numeric score and a clear understanding category.

The approved MVP categories are:

1. **Understood well**
2. **Partially understood**
3. **Needs revision**
4. **Needs teacher support**
5. **Not completed**

The first four categories are numeric categories. Each institution configures their score ranges, and those ranges must cover the full 0–100 scale without gaps or overlaps.

**Not completed** is different. It is not a low-score band. It is used only when required Homework, Blitz, or both can no longer validly be completed. A submission waiting for Teacher review is not **Not completed**, and a calculated but unreleased result is not **Not completed**.

The final Topic score is calculated from the official Homework and Blitz scores using the institution's acceptable-difference threshold:

- If `|Homework - Blitz| <= threshold`, Final = `(Homework + Blitz) / 2`.
- If `|Homework - Blitz| > threshold`, Final = `Blitz`.

All Homework/Blitz comparison and final-score calculation use unrounded internal values. Scores shown to users are rounded to **one decimal place** using standard mathematical rounding. Understanding categories use a separate integer `category_score`: `.0`–`.5` rounds down and `>.5` rounds up; institution category ranges cover integers 0–100 without gaps or overlaps.

Result calculation and result visibility are separate.

For Student visibility, each institution supports:

- **Automatically after the result is fully calculated**
- **Manually released by the Teacher**

For Parent visibility, each institution supports:

- **Automatically after the Student result is released**
- **Manually released by the Teacher**
- **Hidden from Parents**

A Parent must never receive a Topic result before that result has been released to the Student.

The platform should also show whether Homework and Blitz were consistent or inconsistent. This status is an educational signal for the Teacher, not an automatic accusation.

## 12. MVP Scope

The MVP version of **TestLabUz** focuses on the complete Topic learning-check workflow from preparation through final understanding assessment.

### Multi-Institution Foundation

The MVP supports multiple educational institutions from the beginning. Each institution has separate users, groups, Topics, materials, tasks, submissions, results, settings, and reports.

### Approved Roles and Devices

- Platform Owner / Super Admin — desktop
- Institution Admin — desktop
- Teacher — desktop and mobile
- Student — desktop and mobile
- Parent — mobile

### Learning Materials

Teachers can upload PDF, DOCX, PPT, and PPTX learning materials. The platform maximum is **25 MB per learning-material file**. Institutions may configure lower limits.

### Assignment Types

The MVP supports:

1. Single-choice
2. Multiple-choice
3. True / false
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching
8. Ordering
9. Fill-in-the-blank

Objective questions are automatically checked where applicable. Questions requiring judgment are manually reviewed by the Teacher. For Multiple-choice, the Student may select at most as many options as there are correct answers, and partial credit is based only on the proportion of correct options actually selected. Matching, ordering, and multi-blank questions use their approved component-based partial-credit rules.

Student answer files may use PDF, DOCX, PPT, and PPTX and have a platform maximum of **15 MB per file**, with lower institution limits allowed.

### Official Topic Assessment Pair

A Topic may have multiple Homework and Blitz tasks, but exactly one **whole-group Homework** and one **whole-group Blitz** are designated as the official result-bearing pair. Selected-Student tasks are practice-only. The official Student cohort is snapshotted when the first official task becomes active and reused for both official tasks.

The designated pair and cohort cannot be replaced after Student attempt activity begins.

### Attempts

- Homework: exactly **3 normal attempts**.
- Official Homework score: **highest valid completed score**.
- Blitz: exactly **1 normal attempt**.
- Blitz exception: the Teacher may grant **1 additional Student-specific attempt** for a valid technical or other exceptional reason and must record the reason.

Attempt history is preserved.

### Blitz Timing

The Teacher configures each Blitz duration. The Institution Admin selects the institution's timer-start mode:

- synchronized start; or
- individual Student start.

At timeout, the backend automatically finalizes saved answers. Unanswered questions receive zero.

### Result Calculation

Both official task scores use a 0–100 scale.

Let `H = Homework`, `B = Blitz`, `D = |H - B|`, and `T = institution threshold`.

- `D <= T` → Final = `(H + B) / 2`
- `D > T` → Final = `B`

Calculation uses unrounded values; category assignment uses the derived integer `category_score`. User-facing scores are displayed with one decimal place.

### Result Visibility

Student result-release mode:

- automatic after full calculation; or
- manual Teacher release.

Parent result-visibility mode:

- automatically after Student release;
- manual Teacher release; or
- hidden.

Parent visibility cannot precede Student visibility.

### Timezone

Authoritative timestamps are stored as UTC instants. Each institution has one IANA timezone for educational scheduling and display. For institutions operating in Uzbekistan, the initial default is `Asia/Tashkent`. Device clocks cannot change deadlines or Blitz timing.

### Core MVP Outcome

The MVP is successful when a Teacher can create a Topic, provide materials, assign official Homework, run an official in-class Blitz, complete automatic/manual checking, compare the two official scores, obtain the correct final result and understanding category, and release that result according to institution policy.

## 13. Multi-Institution Model

**TestLabUz** is built to support many educational institutions from the beginning.

Each institution has its own logical workspace and independently manages its authorized users, groups, learning process, settings, and reports. Data from one institution must never become accessible to users from another institution through navigation, direct links, identifiers, filters, files, or reports.

Each institution manages its own:

- Institution Admins
- Teachers
- Students
- Parents
- Groups or classes
- Teacher-group assignments
- Student-group assignments
- Parent-Student relationships
- Topics
- Learning materials
- Homework
- Blitz tasks
- Submissions and attempts
- Results and reports
- Acceptable Homework–Blitz difference threshold
- Understanding-category ranges
- Blitz timer-start mode
- Student result-release mode
- Parent result-visibility mode
- Institution timezone
- Learning-material and Student-submission upload limits within platform maximums

Attempt counts are **not institution-configurable** in the MVP. Homework always has three normal attempts, and Blitz normally has one attempt plus at most one Teacher-approved Student-specific exception attempt.

Institutions can configure business settings without affecting other institutions. Changes to settings must not silently rewrite historical closed results.

This model allows TestLabUz to serve schools, universities, learning centers, and other organizations through one platform while preserving clear ownership, privacy, and institution-specific educational rules.

## 14. Platform Requirements

**TestLabUz** should be simple enough for non-technical educational users while enforcing the approved business rules consistently.

Teachers and Students use both desktop and mobile interfaces. Institution Admins and the Platform Owner / Super Admin use desktop interfaces. Parents use a mobile interface.

The platform must support multiple institutions from the beginning and enforce strict data separation between them.

The MVP supports PDF, DOCX, PPT, and PPTX learning materials with a **25 MB platform maximum per learning-material file**. Student file-based answers have a **15 MB platform maximum per file**. Institution Admins may configure lower limits but cannot exceed the platform maximums.

The platform must support all nine approved assignment types and the approved automatic, manual, and partial-credit checking rules.

Homework and Blitz attempt behavior is fixed for the MVP: three Homework attempts with the highest valid completed score, and one normal Blitz attempt with one possible Teacher-approved Student-specific exception.

Blitz uses a whole-task duration configured by the Teacher. The institution configures whether the timer starts synchronously for everyone or individually when each Student begins. Server time must be authoritative, and timeout must automatically finalize saved work.

The platform must use the approved Homework–Blitz comparison formula, preserve unrounded calculation precision, display scores with one decimal place, and assign understanding categories from the derived integer `category_score`.

The platform must keep result calculation separate from result visibility and support both Student release modes and all three Parent visibility modes.

All authoritative timestamps should be treated as UTC instants while educational dates and times are interpreted and shown using the institution's configured IANA timezone.

The platform must enforce role, institution, group, assignment, ownership, and Parent-child relationship restrictions on the server side. Hiding a screen or button is not sufficient authorization.

Detailed architecture, database structure, and API contracts belong in the later technical project documents. This business overview defines the product behavior those technical documents must implement.

## 15. Future Enhancements

After the MVP version of **TestLabUz** is completed and tested in real educational institutions, the application can be improved with additional features.

Future versions may include **AI features**. For example, AI may help teachers generate questions from uploaded materials, create blitz tasks automatically, suggest assignment ideas, analyze written answers, or identify students who may need extra support. AI will not be included in the MVP version, but it can become an important feature later.

The system may also support **audio and video materials** in future versions. Teachers may upload recorded lessons, explanations, voice notes, or video content connected to a topic. Students may also complete audio or video-based assignments when needed.

Future versions may include more advanced assignment options, such as speaking tasks, video responses, interactive exercises, coding tasks, group assignments, and project-based tasks.

The platform may also include more detailed reports and analytics. For example, teachers and admins may see which topics are difficult for most students, which groups are improving, which students often have a big difference between homework and blitz scores, and which students need additional support.

Parents may receive more advanced progress updates in the future, such as notifications, weekly summaries, topic-based progress reports, and recommendations for helping their child study better.

The system may also include communication features, such as teacher-student comments, teacher-parent messages, announcements, and reminders.

In later versions, **TestLabUz** may include a monetization model. For example, institutions may use free access at the beginning, and later the platform may offer paid plans, subscriptions, premium features, or custom licensing for larger institutions.

The main rule for future enhancements is that they should be added step by step. The MVP should first focus on the core idea: topics, materials, assignments, blitz tasks, score comparison, and understanding assessment. Advanced features should only be added after the main workflow works clearly and reliably.

## 16. Business Model Direction

At the beginning, **TestLabUz** will be free to use.

The main goal of the first version is not monetization. The main goal is to build the core product, test it with real educational institutions, collect feedback, and improve the system based on real usage.

In the MVP version, the system should not include paid plans, subscriptions, payment integration, invoices, license management, or premium feature restrictions. These features can be added later after the main learning workflow works properly.

The free version will help schools, colleges, lyceums, universities, institutes, learning centers, and other educational institutions try the platform without financial risk. This will make it easier to understand what institutions really need and which features should be improved first.

In future versions, **TestLabUz** may use different monetization models, such as:

- Subscription plans for institutions
- Free plan with paid advanced features
- Custom licensing for large institutions
- Paid AI features
- Paid advanced reports and analytics
- Paid storage or larger file upload limits
- Premium support for institutions

The final business model should be decided later, after the MVP is tested and the real needs of institutions are better understood.

For now, the business direction is simple: first build a useful and reliable educational platform, then add monetization step by step in future versions.

## 17. Success Criteria

The MVP of **TestLabUz** is successful when real educational institutions can use the complete learning-check workflow reliably from beginning to end.

The main success criteria are:

1. **Platform and institution management works**  
   The Platform Owner can manage institutions, and each Institution Admin can manage the users, groups, relationships, and approved settings inside only their own institution.

2. **Institution data is isolated**  
   Users cannot access another institution's users, Topics, tasks, files, submissions, results, or reports.

3. **Teachers can create Topic-based learning**  
   An authorized Teacher can create Topics for assigned groups and connect learning materials, Homework, Blitz tasks, and results correctly.

4. **Learning materials work within approved limits**  
   Teachers can upload PDF, DOCX, PPT, and PPTX learning materials up to the effective institution limit, never exceeding the 25 MB platform maximum.

5. **All nine assignment types work**  
   The platform supports the approved automatic, manual, and partial-credit checking behavior.

6. **Homework attempts work exactly as defined**  
   Each Student receives three normal Homework attempts, all attempt history is preserved, and the highest valid completed score becomes official.

7. **Blitz attempts and exception handling work correctly**  
   Each Student normally receives one Blitz attempt. A Teacher can grant at most one additional Student-specific attempt for a valid reason, with the reason and affected attempt preserved for traceability.

8. **Both Blitz timer-start modes work**  
   An institution can use synchronized start or individual Student start, while the Teacher controls the Blitz duration.

9. **Blitz timeout is enforced by the server**  
   At timeout, further edits are blocked, saved work is automatically finalized, unanswered questions receive zero, and manual-review answers remain pending where required.

10. **The official Topic assessment pair is unambiguous**  
    A Topic may contain supplementary tasks, but exactly one designated Homework and one designated Blitz determine the official Topic result.

11. **The system calculates the final result correctly**  
    It compares official Homework and Blitz scores using the institution threshold, uses the average when the difference is acceptable, and uses the Blitz score when the difference is too large.

12. **Score precision is consistent**  
    Calculations use unrounded values, category assignment uses the derived integer `category_score`, and user-facing scores are displayed with one decimal place.

13. **Understanding categories are correct**  
    The first four categories follow institution-configured ranges, and **Not completed** is used only for missing required work rather than low performance, pending review, or hidden results.

14. **Result release works according to institution policy**  
    Student results support automatic or manual Teacher release. Parent visibility supports with-Student release, manual Teacher release, or hidden, and never precedes Student release.

15. **Timezone and deadlines are reliable**  
    The system uses authoritative UTC instants and the institution's configured IANA timezone so device-clock changes cannot extend deadlines or Blitz time.

16. **Parents remain read-only and correctly scoped**  
    A Parent sees only permitted information for explicitly connected children.

17. **Historical learning evidence is preserved**  
    Attempts, submissions, official scores, result rules, and closed results remain traceable after later configuration, relationship, status, or archive changes.

18. **The product remains understandable for non-technical users**  
    Teachers, Students, Institution Admins, Parents, and platform staff can use their role-specific workflow without programming or technical knowledge.

The MVP will have proven its core value when Teachers can use TestLabUz to distinguish between home performance and controlled in-class understanding, identify Students who need support, and do so through rules that are consistent, fair, and auditable.

## 18. MVP Exclusions

The MVP version of **TestLabUz** should focus only on the core learning-check workflow. To keep the first version simple, practical, and easier to build, some advanced features will not be included at the beginning.

The MVP will not include **AI features**. The system will not automatically generate questions, analyze written answers with AI, create blitz tasks from uploaded materials, or give AI-based recommendations. These features may be added in future versions.

The MVP will not include **audio and video materials**. Teachers will only upload PDF, DOCX, PPT, and PPTX files in the first version. Audio lessons, video lessons, voice answers, and video responses can be added later.

The MVP will not include **paid plans or monetization features**. There will be no subscription system, payment integration, invoices, license management, premium feature restrictions, or paid storage limits in the first version.

The MVP will not include **advanced analytics**. The system may show basic results and understanding categories, but deep reports, prediction tools, performance trends, and advanced dashboards can be added later.

The MVP will not include **automatic checking for all assignment types**. Some tasks, such as open written answers and file-based assignments, may need to be checked manually by the teacher.

The MVP will not include **communication features** such as teacher-student chat, teacher-parent messages, announcements, reminders, or comments. These features can be added in future versions if needed.

The MVP will not include **advanced parent features**. Parents will mainly be able to view their child’s progress, scores, completed tasks, and understanding categories. They will not manage tasks, contact teachers inside the system, or change learning data.

The MVP will not include **complex institution customization**. Each institution will have its own users, groups, topics, tasks, and results, but advanced custom workflows, custom grading systems beyond basic category settings, and deep branding options can be added later.

The MVP will not include **external integrations** such as Google Classroom, Moodle, Telegram, SMS, email notifications, payment systems, or third-party learning platforms.

The main purpose of excluding these features from the MVP is to avoid making the first version too large and complicated. The first version should prove the core idea: teachers can create topics, upload materials, assign homework, give blitz tasks, compare results, and understand the student’s real learning level.
## Post-Audit MVP Clarifications

The MVP additionally fixes these behaviors:

- Administrator-created Institution Admin, Teacher, Student, and Parent accounts use an initial password and require a mandatory first-login password change before normal application access.
- New institutions start with `Asia/Tashkent`, 25 MB learning-material limit, and 15 MB Student-submission limit; educational-policy settings and numeric category ranges start unconfigured and block only dependent operations until the Institution Admin selects them.
- Multiple-choice exposes only a maximum selection count equal to the number of correct answers; scoring is `correctly_selected / total_correct`, with no extra penalty and zero for an empty answer.
- Automatic Short Written checking uses deterministic normalized exact matching; it does not use fuzzy matching, spelling correction, synonym inference, or AI.
- Draft Homework/Blitz may temporarily total zero points, but activation requires backend-recalculated total points greater than zero.
- If top Homework attempts tie exactly, the earliest tied attempt is the official attempt reference.
- Closing active Homework/Blitz auto-finalizes existing in-progress attempts from saved answers, gives zero to unanswered components, and creates no fake Attempt for Students who never started.
- A Student Topic Result can be closed only after a terminal calculated or definitive Not completed state; closure freezes scoring/result data but remains separate from result visibility/release.
