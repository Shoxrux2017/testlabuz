# Codex Implementation Contract: S08-FE-003 — Teacher Blitz Lifecycle UX

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-003` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter desktop Teacher Blitz Schedule/Official Designation/Activate/Close/Archive UX` |
| Depends on | `S08-FE-001` (PR #262, 15508f3), `S08-FE-002` (PR #264, b5b24b1) — both `Accepted / Delivered`; `S08-BE-PHASE-2 = PASS` remains valid; revalidated 2026-09-24 on `b5b24b1` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Runtime implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Backend API dependency | Final delivered Stage 8 Schedule/Archive, result-pair, Activate and Close APIs after Backend Phase 2 PASS |
| Flutter toolchain | Use the repository's current FVM-pinned Flutter version at implementation time |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | `S08-FE-PHASE-2` after `S08-FE-001…006` are `Accepted / Delivered` |
| Blocks | `S08-FE-004` |

Do not start until:

```text
S08-FE-001 = Accepted / Delivered
S08-FE-002 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
current origin/main re-checked
final delivered Blitz lifecycle/result-pair API inspected
current FE-001/002 Blitz read/builder integration inspected
current Stage 6 Topic result-pair/Homework lifecycle frontend inspected
clean synchronized local main
```

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not invent a new lifecycle, timer, result-pair, idempotency or UX contract.

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S08-FE-001/S08-FE-002 source and focused tests directly required by this task;
5. final delivered Stage 8 backend Schedule/Archive/result-pair/Activate/Close routes/resources directly required to confirm the API already encoded below;
6. current Stage 6 Homework lifecycle/official-designation source directly required as a pattern;
7. current Topic lifecycle/result-pair/session/idempotency/time/error infrastructure directly required by this task.

Do **not** read:

- product docs;
- roadmap files;
- previous Stage 8 task contracts;
- Stage history;
- checkpoint reviews;
- closure reviews;
- unrelated modules

to determine requirements.

This contract already resolves:

- Schedule/Reschedule UX;
- Schedule server-time boundary;
- lifecycle action availability;
- official Blitz designation/add/replace rules;
- locked partial result-pair behavior;
- activation Idempotency-Key ownership;
- activation unknown-outcome handling;
- Close/Archive behavior;
- mutation reconciliation;
- operation serialization;
- Topic open-assessment conflict copy/invalidation;
- desktop/mobile capability boundary;
- error UX;
- accessibility;
- focused tests/verification.

---

# 3. Goal

Complete the core **desktop Teacher Blitz lifecycle UX**.

An authenticated desktop Teacher must be able to:

- schedule a Draft Blitz;
- reschedule a Scheduled Blitz;
- understand that scheduling is planning metadata and does **not** auto-activate;
- designate an eligible whole-group Draft/Scheduled Blitz as the Topic's official Blitz when an official Homework already exists;
- fill the missing Blitz side of an already-locked partial result pair when the backend permits it;
- replace a previously designated preactivity official Blitz while the pair remains replaceable;
- activate an eligible Draft/Scheduled Blitz;
- close an Active Blitz;
- archive an eligible practice Draft/Scheduled Blitz;
- archive a Closed Blitz;
- see authoritative state after every mutation;
- safely recover from uncertain mutation outcomes without automatic replay;
- receive useful conflict guidance.

Mobile remains read-only for these lifecycle controls in FE-003.

`S08-FE-006` later owns:

```text
Teacher live monitoring
attempt-exception grant
mobile Teacher Activate/monitor workflow
```

Do not pre-implement those capabilities here.

---

# 4. Included Backend APIs

Configured Dio base already includes:

```text
/api/v1
```

## 4.1 Schedule / Reschedule

```text
POST /teacher/blitz/{blitzId}/schedule
```

Body:

```json
{
  "scheduled_at": "2026-09-15T09:00:00+05:00"
}
```

Success:

```text
200 OK
Blitz task scheduled successfully.
```

Returns complete authoritative:

```text
TeacherBlitz
```

## 4.2 Archive

```text
POST /teacher/blitz/{blitzId}/archive
```

Request:

```text
empty body
```

Success:

```text
200 OK
Blitz task archived successfully.
```

Returns complete authoritative Blitz.

## 4.3 Result-pair read

Reuse:

```text
GET /teacher/topics/{topicId}/result-pair
```

Existing frontend read controller remains authoritative for official status.

## 4.4 Official Blitz designation

Use:

```text
PUT /teacher/topics/{topicId}/result-pair
```

Body for Stage 8 Blitz designation:

```json
{
  "homework_assessment_id": "current-official-homework-uuid",
  "blitz_assessment_id": "candidate-blitz-uuid"
}
```

Success:

```text
200 OK
Topic result pair updated successfully.
```

Returns authoritative:

```text
TeacherTopicResultPair
```

## 4.5 Activate

```text
POST /teacher/blitz/{blitzId}/activate
```

Required header:

```http
Idempotency-Key: <uuid>
```

Body:

```text
empty
```

Success:

```text
200 OK
Blitz task activated successfully.
```

Returns complete authoritative Blitz.

## 4.6 Close

```text
POST /teacher/blitz/{blitzId}/close
```

No Idempotency-Key.

Body:

```text
empty
```

Success:

```text
200 OK
Blitz task closed successfully.
```

Returns complete authoritative Blitz.

## 4.7 Delivered facts (revalidation 2026-09-24)

Confirmed on `b5b24b1`:

- every success body is exactly `{data, message}` with the messages above; the
  result-pair success message is also returned by a server-side no-op PUT;
- error envelopes are `{message, code, errors}` (`errors` defaults to `{}`), with no
  `request_id`; only `institution_settings_incomplete` adds `meta` (see Section 69);
- Schedule/Close/Archive/Activate require an empty body or `{}` and no query string;
  unknown keys are rejected with `422 validation_failed`;
- no scheduler, job or command activates a Blitz; the only Blitz scheduled command
  reconciles timeouts of `active` Blitz.

---

# 5. Explicit Non-Goals

Do not implement:

- Blitz metadata Create/Edit/Question authoring beyond FE-002 integration;
- automatic activation at scheduled time;
- schedule cancellation/clear;
- timer-mode setting editor;
- Institution settings editor;
- live countdown for Teacher;
- Teacher monitoring API/UI;
- Student status roster;
- Student attempt-exception grant UI;
- Student Blitz execution;
- answer/file UI;
- checking/scoring;
- result comparison;
- Topic result;
- result release;
- mobile Schedule/Reschedule;
- mobile official designation;
- mobile Close/Archive;
- mobile exception grant;
- mobile monitoring;
- automatic lifecycle transitions from device clock;
- optimistic mutation success;
- automatic mutation replay;
- new package;
- backend changes;
- platform changes;
- full frontend suite/build/E2E.

Do not add dead/disabled Monitoring or Exception buttons.

---

# 6. No New Flutter Route

S08-FE-003 adds **no new route**.

All controls live on the existing FE-001:

```text
TeacherBlitzDetailScreen
```

Schedule uses a dialog.

Official designation uses confirmation dialogs.

Lifecycle uses confirmation dialogs.

No new ShellRoute.

No `/schedule` screen.

---

# 7. Desktop / Mobile Capability Boundary

## Desktop

FE-003 controls are available according to confirmed current state.

## Mobile

Keep FE-001 read-only Blitz detail:

- no Schedule;
- no Official designation mutation;
- no Activate;
- no Close;
- no Archive.

Do not change mobile routing.

Do not show disabled lifecycle buttons.

S08-FE-006 later adds the specifically approved mobile runtime capabilities.

---

# 8. Stage 8 Lifecycle UX Projection

Client action visibility is a UX hint only.

Backend remains authoritative.

For confirmed current Blitz:

## Draft

Potential desktop actions:

```text
Schedule
Activate
Archive      // only when safe practice status is known; see Section 33
Set/Replace Official Blitz  // when eligible; see result-pair sections
```

## Scheduled

Potential:

```text
Reschedule
Activate
Archive      // only when safe practice status is known
Set/Replace Official Blitz
```

## Active

Show:

```text
Close
```

No Schedule.

No Archive.

No new official designation if it was not already official.

## Closed

Show:

```text
Archive
```

## Archived

No lifecycle mutation actions.

No same-target action button.

---

# 9. Schedule Is Planning Metadata, Not Auto-Activation

This must be explicit in UI.

Show near schedule controls:

```text
Scheduling records the planned Blitz time.
The Blitz does not start automatically.
The Teacher must still activate it.
```

Do not create a client timer that auto-calls Activate.

Do not imply Laravel Scheduler will activate a Blitz.

There is no automatic activation workflow in Stage 8.

---

# 10. Schedule Action Availability

Show:

```text
Schedule
```

for confirmed:

```text
Draft
```

Show:

```text
Reschedule
```

for confirmed:

```text
Scheduled
```

Do not show for:

```text
Active
Closed
Archived
```

A Draft may already carry a non-null `scheduledAt` from another client.

It still uses the label:

```text
Schedule
```

because the lifecycle status has not transitioned to `scheduled`.

---

# 11. Schedule Dialog

Create:

```text
TeacherBlitzScheduleDialog
```

or equivalent focused presentation.

Title:

## Draft

```text
Schedule Blitz
```

## Scheduled

```text
Reschedule Blitz
```

Content:

```text
Institution timezone: <timezone>
Planned date/time
```

Helper:

```text
Scheduling does not activate the Blitz automatically.
```

Buttons:

```text
Cancel
Schedule
```

or:

```text
Cancel
Reschedule
```

No mutation before confirmation.

---

# 12. Schedule Initial Value

If authoritative:

```text
scheduledAt != null
```

convert it to Institution wall clock using:

```text
InstitutionTimezone.instantToWallClock(...)
```

and prefill the dialog.

If null:

- no server time is invented;
- initial date/time may be blank and Teacher selects it.

Do not default to device current time as authoritative schedule.

---

# 13. Schedule Timezone Authority

Use:

```text
blitz.institutionTimezone
```

from the strict FE-001 resource.

Resolve through the existing:

```text
InstitutionTimezone
```

helper.

Do not use device timezone.

If Institution timezone cannot resolve:

- do not send Schedule;
- show:
  ```text
  Institution timezone is unavailable.
  ```
- allow close/refresh dialog.

---

# 14. Schedule Local Validation

Validate only client-safe input properties:

- a date is selected;
- a time is selected;
- selected wall clock exists in the IANA Institution timezone;
- serialized timestamp has explicit offset.

Do **not** use device clock to reject:

```text
past
now
future
```

The backend server clock decides whether `scheduled_at` is sufficiently future.

This prevents a wrong device clock from blocking a valid schedule.

---

# 15. Schedule Serialization

Use:

```text
InstitutionTimezone.serializeWallClock(...)
```

Expected:

```text
YYYY-MM-DDTHH:mm:ss±HH:mm
```

Send one immutable:

```text
TeacherBlitzScheduleRequest
```

No other fields.

---

# 16. Scheduled Same-Instant No-Op

When authoritative status is:

```text
Scheduled
```

and selected wall clock resolves to the exact same absolute instant as current:

```text
scheduledAt
```

then:

- do not send POST;
- close/retain dialog according to current UX pattern;
- show:
  ```text
  Blitz is already scheduled for this time.
  ```

No server timestamp churn.

Important:

For status:

```text
Draft
```

even if `scheduledAt` already equals the chosen value, **send Schedule**.

The POST is still required to transition:

```text
Draft -> Scheduled
```

---

# 17. Schedule Repository Extension

Extend:

```text
TeacherBlitzRepository
```

with:

```dart
Future<TeacherBlitz> scheduleBlitz(
  String blitzId,
  TeacherBlitzScheduleRequest request,
);
```

Do not merge Schedule into metadata PATCH.

Do not add schedule fields back into FE-002 form.

---

# 18. Schedule Remote Data Source

Request:

```text
POST /teacher/blitz/{encodedBlitzId}/schedule
```

Requirements:

- canonical Blitz UUID;
- exact JSON body:
  ```json
  {"scheduled_at":"..."}
  ```
- no query;
- followRedirects false;
- require `200`;
- require exact success message:
  ```text
  Blitz task scheduled successfully.
  ```
- parse returned complete TeacherBlitz using FE-001 strict DTO.

---

# 19. Schedule Mutation Uncertainty

Schedule may commit before reliable client response.

Do not automatically replay.

On uncertain result:

1. retain requested absolute scheduled instant;
2. enter `reconciling`;
3. GET exact Blitz detail;
4. adopt authoritative resource when target matches.

Classify confirmed success only when:

```text
current.status == scheduled
AND
current.scheduledAt == requested absolute instant
```

If not:

```text
outcomeReview
```

Feedback:

```text
The schedule update could not be confirmed.
Review the current Blitz schedule before trying again.
```

Provide:

```text
Check current Blitz
```

GET only.

No automatic POST replay.

---

# 20. Schedule Validation Failure

For:

```text
422 validation_failed
errors.scheduled_at
```

show:

```text
The server rejected this scheduled time.
Choose a future time in the Institution timezone and try again.
```

This is server-authoritative.

Do not compare against device `DateTime.now()` to decide future eligibility.

Keep dialog/form editable.

Revalidation 2026-09-24 — delivered Schedule matrix (`ScheduleTeacherBlitz`,
`TeacherBlitzPreparationGuard`, `InstitutionBlitzScheduledAt`):

```text
422 validation_failed, errors.scheduled_at -> not strictly after server now,
                                              offset not equal to the Institution
                                              offset at that instant, or bad syntax
                                              (`Z` rejected; numeric offset required)
409 task_closed        -> Blitz closed
409 task_archived      -> Blitz archived
409 business_conflict  -> Blitz active, or any existing Attempt
409 topic_not_editable -> Topic not draft|active
```

The server also no-ops a Scheduled Blitz whose instant is unchanged; the Section 16
client no-op remains required. For the definite 409 codes, refresh the Blitz detail
and show:

```text
task_closed        -> This Blitz is closed.
task_archived      -> This Blitz is archived.
topic_not_editable -> The Topic is no longer editable.
business_conflict  -> Scheduling is not available in the current server state.
                      Refresh the Blitz before trying again.
```

No automatic Schedule replay.

---

# 21. Result-Pair Repository Extension

Keep existing:

```text
setOfficialHomework(topicId, homeworkId)
```

behavior intact.

Stage 8 backend semantics mean omitting:

```text
blitz_assessment_id
```

preserves an already-populated Blitz side.

Do not alter Stage 6 Homework UI to clear Blitz accidentally.

Add:

```dart
Future<TeacherTopicResultPair> setOfficialBlitz(
  String topicId, {
  required String homeworkId,
  required String blitzId,
});
```

Exact body:

```json
{
  "homework_assessment_id": "homeworkId",
  "blitz_assessment_id": "blitzId"
}
```

No null clear operation.

---

# 22. No Official Blitz Without Official Homework

The Stage 8 result-pair mutation still requires:

```text
homework_assessment_id
```

Therefore when confirmed Topic pair is:

```text
null
```

the frontend does **not** attempt Blitz-only designation.

Show informational guidance on whole-group Draft/Scheduled Blitz:

```text
Choose the Topic's official Homework first.
Then this Blitz can be designated as the official Blitz.
```

Do not invent:

- arbitrary Homework selection inside the Blitz dialog;
- null/empty Homework ID;
- a second pair-creation workflow.

The existing Stage 6 official Homework UX is the path for creating the Homework
side.

---

# 23. Official Blitz Eligibility — Candidate

A non-current Blitz may offer official designation only when all confirmed local
read conditions are true:

```text
desktop
Blitz assignmentMode = group
Blitz status = draft|scheduled
result-pair read is confirmed
result-pair exists
```

Backend still validates:

- Tenant/Teacher;
- Topic;
- no Attempts;
- current official Blitz replaceability;
- lock state;
- assignment;
- lifecycle.

Do not infer Attempt existence locally.

---

# 24. Already Official Blitz

When confirmed pair has:

```text
pair.blitzAssessmentId == blitz.id
```

show:

```text
Official
```

badge/read status.

Do not show:

```text
Set official
Replace official
```

for the same Blitz.

This remains true after Blitz becomes:

```text
Active
Closed
Archived
```

because the pair is historical identity.

---

# 25. Fill Missing Blitz Side — Unlocked Pair

When:

```text
pair exists
pair.blitzAssessmentId == null
pair.lockedAt == null
candidate = whole-group Draft|Scheduled
```

show:

```text
Set as Official Blitz
```

Confirmation:

```text
Set this Blitz as the Topic's official Blitz?
The current official Homework will be preserved.
The server will validate whether this Blitz is still eligible.
```

---

# 26. Fill Missing Blitz Side — Locked Partial Pair

When:

```text
pair exists
pair.blitzAssessmentId == null
pair.lockedAt != null
candidate = whole-group Draft|Scheduled
```

the backend explicitly permits a one-time fill of the missing Blitz side while
preserving:

```text
Homework identity
locked cohort
pair lock
designation history
```

Therefore the frontend still shows:

```text
Set as Official Blitz
```

Confirmation text:

```text
This Topic's official cohort is already locked.
This Blitz will use the existing official cohort.
The Homework and cohort cannot be changed by this action.
```

Do not disable the action merely because:

```text
pair.lockedAt != null
```

when the Blitz side is still null.

This is a critical Stage 8 rule.

---

# 27. Replace Existing Official Blitz — Unlocked Pair

When:

```text
pair.blitzAssessmentId != null
pair.blitzAssessmentId != current Blitz
pair.lockedAt == null
candidate = whole-group Draft|Scheduled
```

show:

```text
Replace Official Blitz
```

Confirmation:

```text
Replace the currently designated official Blitz with this Blitz?
The official Homework will remain unchanged.
The server will reject the change if official activity or another lock now prevents replacement.
```

No optimistic badge change.

---

# 28. Populated Locked Pair

When:

```text
pair.blitzAssessmentId != null
pair.blitzAssessmentId != current Blitz
pair.lockedAt != null
```

do not show replacement action.

Show optional informational text:

```text
Official Blitz selection is locked by existing official activity.
```

No PUT attempt.

---

# 29. Selected-Student Blitz

When:

```text
assignmentMode = selected_students
```

never show official designation action.

Show FE-002 informational note/read label as appropriate:

```text
Selected-student Blitz cannot be the official Topic Blitz.
```

Backend remains final authority.

---

# 30. Active / Closed / Archived Non-Official Candidate

A Blitz that is not already official cannot newly become official from FE-003
when its confirmed lifecycle is:

```text
active
closed
archived
```

Do not show designation control.

Backend candidate contract is Draft/Scheduled.

Do not attempt a PUT and rely on failure for normal UX.

---

# 31. Official Designation Mutation Uncertainty

Result-pair PUT is not automatically replayed.

On uncertain outcome:

1. retain requested candidate Blitz ID and current required Homework ID;
2. GET current result pair;
3. publish authoritative pair into existing:
   ```text
   teacherTopicResultPairControllerProvider(topicId)
   ```
4. classify success only when:
   ```text
   pair.homeworkAssessmentId == requested Homework ID
   pair.blitzAssessmentId == requested Blitz ID
   ```

If pair differs/null:

```text
outcomeReview
```

Feedback:

```text
The official Blitz update could not be confirmed.
Review the current official Homework and Blitz before trying again.
```

Provide `Check current official pair`.

No automatic PUT replay.

---

# 32. Official Designation Definite Conflicts

Recognize machine codes.

## `official_task_requires_group_assignment`

```text
Only a whole-group Blitz can be the official Blitz.
```

Refresh Blitz detail and pair.

## `result_pair_locked`

```text
Official Blitz selection is locked by the current server state.
```

Refresh pair.

Important:

A locked pair with `blitzAssessmentId == null` is still a legal fill case.
If backend returns `result_pair_locked` during such an attempted fill, current
server state changed or candidate was no longer eligible; show refreshed state.

## `business_conflict`

```text
This Blitz cannot become the official Blitz in the current server state.
Refresh the Blitz and official pair before trying again.
```

## `topic_not_editable`

```text
The Topic is no longer editable.
```

## `resource_not_found`

Privacy-safe unavailable copy.

No human-message parsing.

Revalidation 2026-09-24 — delivered result-pair rules (`SetTeacherTopicResultPair`,
`TeacherTopicResultPairUpdateRequest`):

- `blitz_assessment_id` is optional but never nullable: an explicit `null` is
  `422`; omitting it preserves the existing Blitz side. Never send `null`.
- A Homework-only body with a different Homework ID while a Blitz side exists is
  `result_pair_locked`; the delivered Stage 6 controller already treats a populated
  Blitz side as non-replaceable, so no Stage 6 change is required.
- Candidate checks in order: not group -> `official_task_requires_group_assignment`;
  Attempts -> `result_pair_locked`; status not `draft|scheduled` or recipient rows
  present -> `business_conflict`; candidate outside the Topic -> `404`.
- Locked pair + null Blitz side -> fill allowed. Locked pair + another Blitz ->
  `result_pair_locked`. Unlocked pair + another Blitz -> replacement allowed only
  while the current official Blitz is still `draft|scheduled`, group-assigned and
  without Attempts; otherwise `result_pair_locked`.
- Activation sets `cohort_snapshotted_at` only; `locked_at` is set by the first
  Student Attempt. An unlocked pair whose official Blitz is already Active can
  therefore still show `Replace Official Blitz` per Section 58; the server rejects
  it with `result_pair_locked`, which is handled by the mapping above. Do not add a
  local Blitz-status inference for the other Blitz.

---

# 33. Archive Visibility — Draft / Scheduled

Backend rejects archiving a preactivation official Blitz.

Frontend should avoid presenting Archive when official status is confirmed.

## Selected-Student Draft/Scheduled

Safe to show:

```text
Archive
```

because selected-Student Blitz cannot be official.

## Whole-group with confirmed pair

If:

```text
pair == null
```

or:

```text
pair.blitzAssessmentId != current.id
```

show Archive.

If:

```text
pair.blitzAssessmentId == current.id
```

do not show Archive.

Show:

```text
Official Blitz must be activated/closed before it can be archived.
```

or replacement must occur first if the pair is still replaceable.

## Whole-group with result-pair read loading/error/unconfirmed

Do not show preactivation Archive.

Reason:

> The client cannot safely prove it is practice-only.

Show a small:

```text
Official Blitz status must be refreshed before archiving.
```

with existing pair Retry/Refresh affordance.

This is a UX safety choice; backend remains authoritative.

---

# 34. Archive Visibility — Closed

For:

```text
Closed
```

show:

```text
Archive
```

regardless of official designation.

Backend will reject if an unexpected in-progress Attempt still exists.

Do not inspect Student Attempts locally.

---

# 35. Archive Confirmation

Title:

```text
Archive Blitz?
```

Body:

```text
Archived Blitz remains historical and read-only.
```

For Closed official Blitz, no special pair mutation occurs.

Buttons:

```text
Cancel
Archive
```

No mutation before confirmation.

---

# 36. Archive Repository Method

Extend:

```text
TeacherBlitzRepository
```

with:

```dart
Future<TeacherBlitz> archiveBlitz(String blitzId);
```

No Idempotency-Key.

No body/query.

Require exact success resource/message.

---

# 37. Archive Unknown Outcome

Do not replay automatically.

On uncertain response:

1. GET exact Blitz;
2. if:
   ```text
   status == archived
   ```
   treat as reconciled success;
3. otherwise:
   ```text
   outcomeReview
   ```
4. show current state.

No automatic Archive replay.

Revalidation 2026-09-24 — delivered Archive matrix (`ArchiveTeacherBlitz`):

```text
already archived                               -> 200 no-op (same message)
active                                         -> 409 business_conflict
official draft|scheduled (pair Blitz side)     -> 409 business_conflict
draft|scheduled with any Attempt               -> 409 business_conflict
closed with an in-progress Attempt             -> 409 business_conflict
practice draft|scheduled, closed (official or not) -> archived
```

The Topic status is not checked by Archive. For `409 business_conflict`, refresh the
Blitz detail and the Topic result pair and show:

```text
This Blitz cannot be archived in the current server state.
Refresh the Blitz and official pair before trying again.
```

---

# 38. Activate Action Availability

Show desktop:

```text
Activate
```

for confirmed:

```text
Draft
Scheduled
```

Do not show for:

```text
Active
Closed
Archived
```

Manual activation does **not** wait for `scheduledAt`.

A Scheduled Blitz may be activated before its planned time.

Do not disable Activate because:

```text
scheduledAt > device time
```

or:

```text
scheduledAt > server-like guessed time
```

Backend allows manual activation independent of schedule metadata.

---

# 39. Activate Confirmation

Title:

```text
Activate Blitz?
```

Body:

```text
The server will snapshot the Institution's current Blitz timer-start mode.

If the mode is synchronized, activation starts the common class timer immediately.

If the mode is individual, activation makes the Blitz available and each Student's timer starts when that Student starts the attempt.

The scheduled time does not activate the Blitz automatically.
```

Buttons:

```text
Cancel
Activate
```

No mutation before confirmation.

Do not claim which timer mode is currently configured before server activation.

---

# 40. Activation Idempotency Key

Use existing:

```text
IdempotencyKeyGenerator
idempotencyKeyGeneratorProvider
```

Generate exactly one UUID for one logical activation operation.

Send:

```http
Idempotency-Key: <generated uuid>
```

Do not generate a new key during automatic reconciliation.

Do not expose the key in UI/logs.

---

# 41. Activation Repository Method

Extend:

```text
TeacherBlitzRepository
```

with:

```dart
Future<TeacherBlitz> activateBlitz(
  String blitzId, {
  required String idempotencyKey,
});
```

Data source:

```text
POST /teacher/blitz/{blitzId}/activate
```

Headers:

```text
Idempotency-Key
```

No body/query.

Require:

```text
200
Blitz task activated successfully.
```

Strict returned Blitz parsing.

---

# 42. Activation Logical Key Lifetime

The activation controller owns:

```text
pendingActivationKey
```

from user-confirmed Activate until one of these terminal client outcomes.

It must also know whether the currently executing POST is:

```text
initial_send
same_key_retry
```

This is controller operation context, not an API field.

The distinction is mandatory because a completed same-key replay may return the
**current** Blitz lifecycle after the original activation, including
`closed|archived`.

## Confirmed success

Clear key and the send-kind context only after the response passes the
context-sensitive validation in Section 46.

## Definite server failure

Clear key and send-kind context.

A later new user activation attempt generates a new key.

## Unknown outcome

Keep the same key while outcome is unresolved.

Do not silently generate another key.

An explicit Retry changes only the send-kind context to:

```text
same_key_retry
```

while preserving the exact same Idempotency-Key.

---

# 43. Activation Unknown Outcome Reconciliation

On timeout/network/malformed-success/unrecognized response:

1. enter `reconciling`;
2. GET exact Blitz detail;
3. adopt authoritative current resource.

If:

```text
current.status == active
```

treat user intent as reconciled success:

```text
Blitz is active.
```

Clear pending key.

Refresh result pair because activation may have established official cohort
metadata.

If current remains:

```text
draft
scheduled
```

do **not** auto-replay.

Enter:

```text
outcomeReview
```

Offer:

```text
Retry activation
Check current Blitz
```

Explicit Retry uses the **same pending Idempotency-Key**.

If current is:

```text
closed
archived
```

do not retry.

Show current authoritative state and clear/retire pending operation.

---

# 44. Activation Same-Key Explicit Retry

Explicit Retry is allowed only when:

```text
same Teacher session
same Blitz target
same pending logical activation operation/key
current confirmed Blitz status = draft|scheduled
no other Blitz route mutation active
```

Send the same Idempotency-Key and mark this POST internally as:

```text
same_key_retry
```

Do not generate a new key for that retry.

This is not automatic replay.

The Teacher explicitly chooses Retry after current-state review.

Important race:

> The reviewed `draft|scheduled` state may become stale before the retry reaches
> the backend. If the original logical activation already completed and the
> Blitz subsequently became `closed|archived`, the backend may validly replay
> the completed activation with the **current** lifecycle resource.

Section 46 defines how to accept that historical replay safely.

---

# 45. Activation Definite Error UX

Map exact machine codes.

## `institution_settings_incomplete`

Show:

```text
The Institution's Blitz timer-start setting is not configured.
Ask the Institution Admin to complete the Blitz timer setting before activation.
```

Do not attempt to edit Institution settings from Teacher UI.

Optional backend `meta.missing_fields` is not required for control flow.

## `assessment_has_no_scoreable_points`

```text
This Blitz needs at least one scoreable Question before activation.
Review the Questions and points.
```

Provide working desktop:

```text
Manage Questions
```

when FE-002 route remains current/usable.

## `assessment_not_assigned`

```text
The server could not establish a valid assigned Student set.
Review the Blitz assignment or current Group membership.
```

If assignment mode is selected and status remains Draft/Scheduled, provide:

```text
Edit Blitz
```

For group assignment, do not imply selected-Student edit will solve lack of group
members.

## `official_cohort_mismatch`

```text
The official Blitz cohort does not match the Topic's established official cohort.
Refresh the official pair and Blitz before continuing.
```

No client repair.

## `topic_not_editable`

Topic no longer editable/active for activation.

## `task_closed` / `task_archived`

Adopt refreshed lifecycle and stop.

## `business_conflict`

Generic server-state conflict with Refresh.

## `idempotency_key_reused`

Treat as a safety conflict:

```text
The activation request could not be safely replayed.
Refresh the Blitz before starting another activation.
```

Do not generate a new key automatically.

Revalidation 2026-09-24 — delivered Activation behavior (`ActivateTeacherBlitz`,
`IdempotencyGuard`, `TeacherOfficialAssessmentCohort`):

- `Idempotency-Key` must be a UUID (stored lowercase); missing/invalid -> `422
  validation_failed` (`errors.idempotency_key`). The frontend never omits it.
- A completed key replays the **current** Blitz with `200` and the same message
  (Section 46.2). The same key for another Blitz -> `409 idempotency_key_reused`.
- A **new** key on an already-Active Blitz returns `200` with the current Active
  resource and does not re-activate. Section 46.1 accepts it (status `active` with
  activation evidence) and shows `Blitz activated successfully.`; no extra rule.
- A new key on Closed/Archived -> `task_closed`/`task_archived`; Topic or Group not
  active -> `topic_not_editable`.
- `business_conflict` covers invalid metadata/Questions, an official pair whose Blitz
  is not group-assigned, official-assessment mismatch, pair lock/attempt
  inconsistency, existing Attempts, and existing group recipient rows.
  Activation never returns `official_task_requires_group_assignment`.
- A persisted incomplete idempotency record surfaces as `500`; treat it as an
  unknown outcome (Section 43).

---

# 46. Activation Success / Completed-Replay Reconciliation

Every HTTP `200` activation response must first pass the strict FE-001
`TeacherBlitzDto` and exact success-message validation.

Always require:

```text
id == target.blitzId
topicId == target.topicId
```

Then validate lifecycle according to the controller's send kind.

## 46.1 Fresh initial activation response

For:

```text
initial_send
```

require:

```text
status == active
timerStartModeSnapshot != null
activatedAt != null
```

A first-send `200` carrying:

```text
closed
archived
draft
scheduled
```

is not accepted as confirmed fresh activation.

Treat an otherwise possible-success malformed/contradictory response through the
existing unknown-outcome reconciliation path.

## 46.2 Completed same-key replay

For:

```text
same_key_retry
```

the backend may return the current authorized resource for the already-completed
logical activation.

Accept exactly these lifecycle states:

```text
active
closed
archived
```

and require historical activation evidence:

```text
activatedAt != null
timerStartModeSnapshot != null
```

For synchronized activation, the ordinary FE-001 lifecycle/timing invariants
must still require the persisted synchronized end. For individual activation,
the ordinary FE-001 invariant remains authoritative.

Reject successful replay shapes:

```text
draft
scheduled
```

because a completed activation cannot legitimately project back to a
pre-activation lifecycle.

Do not require:

```text
status == active
```

for a valid same-key replay after later Close/Archive.

Do not reactivate, reopen, or synthesize an Active state locally.

## 46.3 Adoption after either valid success path

After context-sensitive validation:

1. accept the returned **current** authoritative Blitz into FE-001 detail;
2. refresh FE-001 Blitz list retaining query;
3. refresh existing Topic result-pair controller because the historical
   activation may have established official cohort metadata;
4. clear pending activation key/send-kind context;
5. remain on Blitz detail.

Feedback:

```text
active
-> Blitz activated successfully.

closed replay
-> Activation was confirmed. This Blitz is now closed.

archived replay
-> Activation was confirmed. This Blitz is now archived.
```

A valid Closed/Archived replay is a confirmed successful historical activation,
not `invalidResponse`, not `uncertain`, and not permission to perform another
activation.

No automatic navigation to monitoring in FE-003.

---

# 47. Close Action Availability

Show desktop:

```text
Close
```

only for confirmed:

```text
Active
```

No device-timer condition.

Even if synchronized common end has passed, the Blitz may still be Active until
Teacher closes it.

Do not hide Close because local countdown would be zero.

---

# 48. Close Confirmation

Title:

```text
Close Blitz?
```

Body:

```text
Closing stops further Blitz execution.

The server will freeze any existing in-progress Student attempts.
Attempts whose authoritative deadline has already arrived are finalized by the timeout rule.
```

Buttons:

```text
Cancel
Close
```

Do not inspect Student states locally.

---

# 49. Close Repository Method

Add:

```dart
Future<TeacherBlitz> closeBlitz(String blitzId);
```

Request:

```text
POST /teacher/blitz/{blitzId}/close
```

No body/query.

No Idempotency-Key.

Require exact success resource/message.

---

# 50. Close Unknown Outcome

Do not replay automatically.

On uncertain response:

1. GET exact Blitz;
2. if:
   ```text
   status == closed
   ```
   reconciled success;
3. otherwise outcome review.

Because backend Close is naturally idempotent, a future explicit user action may
be safe, but frontend still follows:

```text
unknown -> GET -> review
```

No automatic POST replay.

---

# 51. Close Definite Errors

Expected:

```text
task_not_active
task_archived
topic_not_editable
business_conflict
resource_not_found
```

Refresh Blitz on 404/409 where session remains valid.

Examples:

## `task_not_active`

```text
This Blitz is no longer active.
```

## `task_archived`

```text
This Blitz is archived.
```

## `topic_not_editable`

```text
The Topic is no longer available for this action.
```

No local repair.

Revalidation 2026-09-24 — delivered Close matrix (`CloseTeacherBlitz`): already
Closed -> `200` no-op (same message); Draft/Scheduled -> `task_not_active`;
Archived -> `task_archived`; only an **Archived** Topic -> `topic_not_editable` (a
Closed Topic may still close its Active Blitz). The delivered Close path produces no
`business_conflict`; keeping it in the recognized set is harmless.

---

# 52. Lifecycle Controller Architecture

Create a focused family controller/state equivalent to:

```text
TeacherBlitzLifecycleController
TeacherBlitzLifecycleState
```

Key:

```text
TeacherBlitzRouteTarget
```

It owns:

```text
Schedule
Activate
Close
Archive
```

Do not put official designation mutation in the same state object if that would
mix pair and Blitz-resource authority.

Preferred:

```text
TeacherBlitzLifecycleController
TeacherOfficialBlitzController
```

both coordinate through one same-route mutation activity boundary.

---

# 53. Lifecycle Controller States

Use a focused representation covering:

```text
idle
submitting
reconciling
confirmedSuccess
definiteFailure
outcomeReview
unavailable
```

Lifecycle state may include:

```text
activeAction
feedback
pendingActivationKey
pendingScheduleInstant
canCheckCurrent
canRetryActivation
```

Do not duplicate the full Blitz object; FE-001 detail remains authoritative.

---

# 54. Lifecycle Action Domain

Create:

```text
TeacherBlitzLifecycleAction
```

for mutation operations:

```text
schedule
activate
close
archive
```

`reschedule` is presentation wording for the same:

```text
schedule
```

backend operation.

Machine action labels must not drive API segments without explicit mapping.

---

# 55. Same-Route Mutation Serialization

FE-002 already introduces Blitz metadata/Question authoring.

FE-003 lifecycle/official operations must not run concurrently with another
same-Blitz mutation.

Use or extend a route mutation activity boundary equivalent to:

```text
TeacherBlitzRouteMutationActivity
```

Operations conceptually include:

```text
metadata
question
schedule
official
activate
close
archive
```

Only one mutation lease on one Blitz route target at a time.

Do not use a global singleton.

Revalidation 2026-09-24 — delivered FE-002 pieces: Question mutations use
`application/teacher_question_mutation_activity.dart`
(`teacherQuestionMutationActivityProvider`, keyed by the shared
`TeacherQuestionAuthoringRouteTarget` that `TeacherBlitzRouteTarget` implements);
Blitz Edit runs on its own route with its own controller generation; there is no
Blitz route mutation activity yet. FE-003 adds one for Schedule/Official/Activate/
Close/Archive following `application/teacher_homework_route_mutation_activity.dart`,
disables lifecycle/official actions while the Question lease is active, and disables
the FE-002 `Edit`/`Manage Questions` entries while a lifecycle/official lease is
active.

---

# 56. Mutation Activity Effects

While any same-Blitz mutation is active:

- disable other lifecycle buttons;
- disable official mutation button;
- FE-002 Edit/Question mutation surfaces must not begin another mutation;
- stale completion from an earlier lease cannot publish after another operation
  takes ownership;
- route/session change invalidates old completion.

Read-only Refresh may be disabled during a committed/unknown mutation where a
concurrent read could confuse outcome handling.

---

# 57. Official Blitz Controller

Create:

```text
TeacherOfficialBlitzController
TeacherOfficialBlitzState
```

Key:

```text
TeacherBlitzRouteTarget
```

Observe:

```text
teacherBlitzDetailControllerProvider(target)
teacherTopicResultPairControllerProvider(topicId)
same-route mutation activity
Teacher session
```

Desktop only.

No official mutation on mobile.

---

# 58. `canSubmitOfficialBlitz` Projection

Create a pure helper equivalent to:

```text
canSubmitOfficialBlitz(...)
```

It returns true only when:

```text
pair state is confirmed
pair != null
Blitz assignment = group
Blitz status = draft|scheduled
candidate is not already pair.blitzAssessmentId
```

Then:

## Pair Blitz null

Allowed regardless of:

```text
pair.lockedAt
```

because locked partial fill is valid.

## Pair Blitz populated with another Blitz

Allowed only when:

```text
pair.lockedAt == null
```

Do not inspect Student Attempts locally.

Backend may still reject current official/candidate due lifecycle/activity races.

---

# 59. Official Mutation Request

When user confirms:

1. require confirmed current pair;
2. use:
   ```text
   homeworkId = pair.homeworkAssessmentId
   blitzId = current Blitz ID
   ```
3. call:
   ```text
   setOfficialBlitz(...)
   ```

Do not send a stale cached Homework ID from elsewhere.

Do not attempt if pair is null.

Do not change Homework selection.

---

# 60. Official Success

On strict success:

1. validate pair:
   ```text
   pair.topicId == target.topicId
   pair.homeworkAssessmentId == requested Homework ID
   pair.blitzAssessmentId == target.blitzId
   ```
2. publish through:
   ```text
   TeacherTopicResultPairController.acceptAuthoritativePair(...)
   ```
3. refresh Blitz list/detail only if needed for UI badges/capability; the PUT does
   not mutate Blitz resource;
4. show:
   ```text
   Official Blitz updated successfully.
   ```
5. remain on detail.

No lifecycle mutation.

---

# 61. Official Pair No-Op / Same Target

If current pair already points to current Blitz:

- do not send PUT;
- no success toast needed;
- show Official badge.

Do not create “Set official” action.

---

# 62. Official Pair Read Loading / Error

If pair state is loading/refreshing without confirmed data:

- do not expose official mutation;
- show current existing loading indicator/read UX.

If pair read is error without confirmed data:

- no official mutation;
- provide existing Retry.

Do not treat missing confirmed data as:

```text
not official
```

for replacement/archive safety.

---

# 63. Archive After Official Designation

After official PUT success on Draft/Scheduled:

- FE-003 preactivation Archive action disappears;
- no pair clear operation exists;
- Teacher can Activate;
- if pair remains replaceable, another eligible Blitz detail can offer Replace.

If pair is locked and current is now official:

- replacement is unavailable;
- activation is the normal path;
- later Close then Archive remains valid.

Do not offer “Remove official” or clear.

---

# 64. Lifecycle Mutation 404

For exact:

```text
404 resource_not_found
```

during lifecycle mutation/reconciliation:

- mark FE-001 Blitz detail `notFound`;
- refresh/invalidate Topic Blitz list;
- lifecycle state becomes unavailable;
- safe feedback:
  ```text
  This Blitz is no longer available.
  ```

No existence detail.

---

# 65. Lifecycle Success Adoption

For Schedule/Activate/Close/Archive confirmed success:

- verify returned target identity;
- call FE-001:
  ```text
  acceptAuthoritativeBlitz(...)
  ```
- call FE-001 list:
  ```text
  refreshAfterMutation(...)
  ```
- refresh result-pair after Activate;
- publish feedback;
- remain on detail.

Do not navigate to Topic automatically.

---

# 66. Lifecycle Unknown Outcome Common Rule

For all non-idempotent/naturally-idempotent lifecycle mutations:

```text
Schedule
Close
Archive
```

and for Activation before its explicit same-key retry branch:

```text
unknown outcome
-> exact GET
-> compare target state
-> classify
```

No automatic mutation replay.

Only Activation has an explicit user-driven same-key Retry after current-state
review.

---

# 67. Common Session Failure Handling

For:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

reuse the existing Teacher session reconciliation.

Do not retain mutation feedback/private Blitz state into a new session.

Pending activation key is discarded on session ownership loss.

---

# 68. API Error Codes

Add/reuse exact `ApiErrorCodes` constants required by FE-003, including:

```text
taskNotActive = task_not_active
taskClosed = task_closed
taskArchived = task_archived
topicNotEditable = topic_not_editable
businessConflict = business_conflict
resultPairLocked = result_pair_locked
officialTaskRequiresGroupAssignment = official_task_requires_group_assignment
assessmentHasNoScoreablePoints = assessment_has_no_scoreable_points
assessmentNotAssigned = assessment_not_assigned
institutionSettingsIncomplete = institution_settings_incomplete
officialCohortMismatch = official_cohort_mismatch
idempotencyKeyReused = idempotency_key_reused
topicHasOpenAssessments = topic_has_open_assessments
```

Reuse existing constants where already present.

Do not duplicate constants in feature files.

Revalidation 2026-09-24: all listed constants already exist except
`institutionSettingsIncomplete` and `officialCohortMismatch`; add exactly those two.

---

# 69. Error Envelope Meta Compatibility

Stage 8 backend may return optional:

```text
meta
```

for:

```text
institution_settings_incomplete
```

with:

```text
missing_fields
```

Frontend control flow uses the stable machine code.

If an exact Blitz mutation error-envelope parser is introduced, it must not
misclassify a valid documented `institution_settings_incomplete` response merely
because it contains documented optional `meta`.

Do not require the UI to expose raw `meta`.

Do not loosen unrelated success DTO strictness.

Revalidation 2026-09-24: the delivered envelope is
`{"message", "code": "institution_settings_incomplete", "errors": {}, "meta":
{"missing_fields": ["blitz_timer_start_mode"]}}` with status `409`. The delivered
FE-002 exact reader in `data/teacher_mutation_transport.dart` accepts only
`message`, `code`, `errors` and optional `request_id`, so it would classify this
documented response as an unknown outcome. FE-003 must accept an optional `meta`
object (a `missing_fields` list of non-empty strings) only for
`409 institution_settings_incomplete`; every other envelope stays exact.

---

# 70. Topic `topic_has_open_assessments` Copy Update

The Stage 6 frontend copy currently refers only to Homework.

Stage 8 backend now blocks Topic close/archive for open:

```text
Homework
and
Blitz
```

Update user-facing feedback to generic wording equivalent to:

```text
Close or archive the Topic's open Homework and Blitz tasks before closing or archiving the Topic.
```

Do not say only Homework.

---

# 71. Topic Open-Assessment Conflict Refresh

When existing Topic lifecycle controller receives:

```text
409 topic_has_open_assessments
```

for Topic Close/Archive:

- refresh authoritative Topic as already done;
- refresh/mark current Homework list state;
- refresh/mark current Blitz list state when those providers exist;
- keep conflict definite;
- show updated generic feedback.

Do not mutate child assessments automatically.

This is a directly required Stage 8 integration correction.

Revalidation 2026-09-24: the delivered `TeacherTopicLifecycleController`
refreshes only the Topic on this conflict and shows the Homework-only copy; the
backend guard (`TeacherTopicOpenAssessmentGuard`) blocks on Homework `draft|active`
or Blitz `draft|scheduled|active`. Refresh the Homework and Blitz list providers
through their existing `refreshAfterMutation` only when they exist.

---

# 72. Topic Lifecycle Mutation Serialization

Do not create a circular lock between Topic lifecycle UI and Blitz route
controller.

Frontend operation serialization is local UI safety only.

Backend is authoritative for races.

It is sufficient that:

- a Blitz detail route mutation disables its own controls;
- Topic close/archive conflict is reconciled from server;
- no optimistic child lifecycle mutation occurs.

Do not create a cross-app global mutation mutex.

---

# 73. Confirmation Accessibility

All confirmation dialogs:

- have explicit title;
- describe irreversible/runtime effect accurately;
- support Cancel;
- default no mutation before confirmation;
- standard keyboard focus/escape behavior unless a mutation is already active;
- do not rely on color.

---

# 74. Detail Screen Integration

Extend FE-002:

```text
TeacherBlitzDetailScreen
```

Desktop action area may contain, according to confirmed current state:

```text
Edit
Manage Questions
Schedule / Reschedule
Set / Replace Official Blitz
Activate
Close
Archive
Refresh
Check current ...  // only when controller outcome requires it
Retry activation   // only for activation outcome-review with preserved key
```

Never show every action simultaneously.

Use Wrap/responsive layout.

No mobile controls from FE-003.

---

# 75. Action Priority / Grouping

Presentation grouping should remain understandable.

Recommended order:

## Authoring / preparation

```text
Edit
Manage Questions
Schedule/Reschedule
Set/Replace Official
```

## Runtime lifecycle

```text
Activate
Close
Archive
```

## Read/recovery

```text
Refresh
Check current
Retry activation
```

Do not encode business priority from button color alone.

Use destructive/confirmation semantics consistent with current Material design.

---

# 76. Busy State

During a lifecycle or official mutation:

- show linear progress or button progress;
- disable conflicting same-route mutations;
- keep read-only detail visible when safe;
- do not show duplicate SnackBars from stale completion;
- do not allow repeated button taps.

---

# 77. Feedback Ownership

Feedback belongs to the current:

```text
Teacher session
Blitz route target
operation generation/lease
```

A completion after:

- logout;
- route target change;
- device surface ownership change;
- newer operation

must not display feedback/navigate/overwrite current state.

`context.mounted` alone is insufficient.

Reuse existing session/lease patterns.

---

# 78. Schedule Dialog Stale Completion

If Teacher session/route changes while Schedule dialog is open:

- returned wall-clock selection is ignored;
- no Schedule request is sent;
- dialog completion does not mutate newer route state.

Capture session/route owner before opening.

---

# 79. Official Confirmation Stale Completion

If confirmation dialog returns after session/target state changed:

- do not issue PUT;
- do not apply pair state.

Use current session/target/operation ownership check.

---

# 80. Activation Confirmation Stale Completion

If activation confirmation returns after session/target change:

- do not generate/send activation key;
- no mutation.

Generate the key only after confirmation and final ownership check.

---

# 81. Schedule vs FE-002 Edit / Question Builder

Same-Blitz operations must serialize.

Examples:

- metadata Save in flight -> Schedule disabled;
- Question mutation in flight -> Activate disabled;
- Schedule in flight -> Edit/Question mutation does not begin;
- official PUT in flight -> Activate disabled.

This prevents UX from producing avoidable stale-authority races.

Backend still handles true multi-client concurrency.

---

# 82. Activation vs Official Designation

Do not allow both current-client mutations simultaneously.

If Activate commits from another client while this UI is about to designate:

- backend may reject designation;
- frontend refreshes pair/Blitz;
- no optimistic official badge.

If designation commits first then Activate:

- activation refreshes pair after success to surface cohort snapshot.

---

# 83. Schedule vs Activation

Both can race across clients.

Within one Flutter route:

- serialize.

If Schedule succeeds first:

```text
status = scheduled
```

then Activate may be performed.

If Activate from another client wins:

Schedule returns/refreshes current Active and no longer offers Schedule.

Do not use local planned time as activation authority.

---

# 84. Archive vs Official State Race

Archive preactivation visibility is a client safety hint only.

If official designation commits concurrently elsewhere:

- backend Archive may return conflict;
- frontend refreshes pair/Blitz;
- no optimistic archived state.

If Archive commits first:

- candidate cannot later be designated due Archived status.

---

# 85. Lifecycle Resource Strictness

All lifecycle mutation success resources use FE-001 strict `TeacherBlitzDto`.

Do not create a looser lifecycle DTO.

The remote data source must not hard-code:

```text
activation 200 => status must be active
```

because lifecycle acceptance depends on controller operation context:

```text
fresh initial activation
vs
completed same-key replay
```

The DTO still validates the resource's own lifecycle invariants strictly; the
controller applies Section 46's operation-specific acceptance rule.

A malformed 2xx response after potential mutation is an **unknown outcome**, not
a confirmed success.

Reconcile via GET.

---

# 86. Result-Pair Resource Strictness

Official mutation success uses existing strict:

```text
TeacherTopicResultPairDto
```

Do not add a second pair DTO.

Stage 8 existing fields:

```text
blitzAssessmentId
```

are already represented.

If the delivered backend adds no new pair field beyond the existing DTO, no
schema change is needed.

---

# 87. No Device-Time Lifecycle Decisions

Do not decide:

```text
can schedule
can activate
should auto-close
timer expired
```

from device current time.

Only state enum and backend response govern lifecycle action visibility.

The Schedule dialog validates wall-clock existence, not server-future business
eligibility.

---

# 88. No Local Activation Timer

After activation returns Active:

- show authoritative:
  ```text
  timerStartModeSnapshot
  activatedAt
  synchronizedEndsAt
  ```
  through FE-001 detail.

FE-003 does not create a ticking countdown.

Teacher live monitoring/countdown-like status belongs to FE-006.

---

# 89. Expected File Scope

Exact filenames may follow delivered FE-002 conventions.

## Create likely

```text
frontend/lib/features/teacher/domain/teacher_blitz_lifecycle.dart
frontend/lib/features/teacher/domain/teacher_blitz_schedule.dart

frontend/lib/features/teacher/application/teacher_blitz_lifecycle_state.dart
frontend/lib/features/teacher/application/teacher_blitz_lifecycle_controller.dart
frontend/lib/features/teacher/application/teacher_official_blitz_state.dart
frontend/lib/features/teacher/application/teacher_official_blitz_controller.dart

frontend/lib/features/teacher/presentation/teacher_blitz_schedule_dialog.dart
```

## Modify likely

```text
frontend/lib/features/teacher/domain/teacher_blitz_repository.dart
frontend/lib/features/teacher/data/teacher_blitz_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_blitz_repository_impl.dart

frontend/lib/features/teacher/domain/teacher_topic_result_pair_repository.dart
frontend/lib/features/teacher/data/teacher_topic_result_pair_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_topic_result_pair_repository_impl.dart

frontend/lib/features/teacher/presentation/teacher_blitz_detail_screen.dart

frontend/lib/features/teacher/application/teacher_topic_lifecycle_controller.dart

frontend/lib/core/network/api_error_codes.dart
```

Modify FE-002 same-route mutation activity files if required to serialize
operations.

No route file changes are expected unless FE-002 delivered helpers require a
narrow correction.

Do not modify:

```text
backend/
platform files
pubspec.yaml
pubspec.lock
Student Blitz frontend
integration_test/
docs/
tasks/
```

---

# 90. Schedule Domain Tests

Create:

```text
teacher_blitz_schedule_test.dart
```

Cover:

- valid wall clock serialization;
- Institution timezone;
- DST/nonexistent wall clock failure;
- no device-future validation;
- Scheduled exact same instant detection;
- Draft same instant is not treated as no-op lifecycle transition;
- request exact JSON key.

---

# 91. Lifecycle Data Source Tests

Create/extend:

```text
teacher_blitz_lifecycle_data_source_test.dart
```

Verify exact:

## Schedule

```text
POST /teacher/blitz/{id}/schedule
body scheduled_at
no idempotency header
200 exact message/resource
```

## Activate

```text
POST /teacher/blitz/{id}/activate
Idempotency-Key exact
no body/query
200 exact message/resource
```

## Close

```text
POST /teacher/blitz/{id}/close
no Idempotency-Key
no body/query
```

## Archive

```text
POST /teacher/blitz/{id}/archive
no key/body/query
```

Verify malformed possible-success responses classify unknown outcome.

Verify documented errors classify definite.

Verify valid activation error with optional `meta` is recognized.

---

# 92. Result-Pair Data Source Tests

Extend existing Topic result-pair tests.

Verify:

## Existing Homework operation

```text
setOfficialHomework
```

still sends only:

```json
{"homework_assessment_id":"..."}
```

and does not clear Blitz.

## New Blitz operation

```json
{
  "homework_assessment_id":"...",
  "blitz_assessment_id":"..."
}
```

Strict resource/message parsing.

Known 409 mapping.

Unknown/malformed possible success -> pair mutation outcome unknown.

---

# 93. Lifecycle Controller Tests

Create:

```text
teacher_blitz_lifecycle_controller_test.dart
```

Cover:

- Draft action projection;
- Scheduled action projection;
- Active -> Close;
- Closed -> Archive;
- Archived none;
- Schedule success;
- Schedule same-instant Scheduled no request;
- Draft same scheduledAt still sends Schedule;
- schedule 422;
- schedule uncertain -> GET match success;
- schedule uncertain -> mismatch outcome review;
- activation creates one idempotency key;
- fresh activation `200 + active` succeeds;
- fresh activation `200 + closed|archived` is not accepted as fresh success;
- activation uncertain -> GET Active reconciled success;
- activation uncertain -> GET Draft/Scheduled preserves key and offers Retry;
- Retry reuses same key and is marked as same-key replay context;
- same-key Retry `200 + active` succeeds;
- same-key Retry after later Close accepts `200 + closed` as confirmed historical activation/current lifecycle;
- same-key Retry after later Archive accepts `200 + archived` as confirmed historical activation/current lifecycle;
- Closed/Archived replay requires non-null `activatedAt` and `timerStartModeSnapshot`;
- same-key Retry `200 + draft|scheduled` is rejected as invalid/unknown success;
- replay adoption never synthesizes/reopens Active;
- definite activation failure clears logical key;
- institution-settings error;
- scoreable-points error;
- assignment error;
- cohort mismatch;
- Close success/uncertain;
- Archive success/uncertain;
- 404 marks detail unavailable;
- stale session/target completion ignored;
- same-route mutation lease serialization.

---

# 94. Official Blitz Controller Tests

Create:

```text
teacher_official_blitz_controller_test.dart
```

Cover:

- no pair -> no mutation/guidance state;
- pair Blitz null/unlocked -> candidate allowed;
- pair Blitz null/locked -> candidate still allowed;
- populated other Blitz/unlocked -> replacement allowed;
- populated other Blitz/locked -> replacement blocked;
- already current -> no mutation;
- selected assignment -> blocked;
- Active non-current -> blocked;
- Closed/Archived non-current -> blocked;
- exact PUT body uses current Homework ID;
- success publishes pair;
- unknown -> pair GET exact match success;
- unknown -> mismatch outcome review;
- result_pair_locked;
- official group conflict;
- business conflict;
- stale completion ignored.

Critical regression:

```text
locked partial pair + null Blitz side remains fillable
```

must have explicit test.

---

# 95. Archive Visibility Tests

Cover presentation/controller helper:

- selected Draft -> Archive visible;
- selected Scheduled -> Archive visible;
- group Draft + confirmed no pair -> visible;
- group Draft + confirmed pair other Blitz -> visible;
- group Draft + confirmed current official -> hidden;
- group Scheduled + current official -> hidden;
- group Draft/Scheduled + pair unconfirmed -> hidden;
- Active -> hidden;
- Closed -> visible;
- Archived -> hidden.

Do not test backend Attempt existence in frontend.

---

# 96. Blitz Detail Screen Tests

Extend FE-002 detail tests.

Desktop:

- Draft actions;
- Scheduled actions;
- Active Close;
- Closed Archive;
- Archived no lifecycle;
- same-key activation replay returning Closed adopts Closed UI and does not show Activate;
- same-key activation replay returning Archived adopts Archived UI and shows no lifecycle mutation;
- schedule helper copy;
- official set/replace states;
- locked partial set-official action;
- locked populated read-only message;
- no-pair official Homework guidance;
- official preactivation Archive hidden;
- activation confirmation copy;
- Close confirmation copy;
- busy progress/controls disabled;
- feedback;
- Check current / Retry activation controls only in proper states.

Mobile:

- no FE-003 lifecycle/designation controls;
- read detail remains visible.

---

# 97. Topic Lifecycle Integration Tests

Update existing Topic lifecycle tests.

Replace Homework-only feedback expectation with generic open-assessment copy.

Test:

```text
topic_has_open_assessments
```

causes current Topic refresh and directly affected Homework/Blitz list refresh
signals without mutating children.

Existing Topic lifecycle success/other failures remain unchanged.

---

# 98. FE-002 Direct Regression

Run focused tests for:

```text
Blitz Edit
Blitz Question Builder
same-route mutation activity
Blitz detail
```

Verify FE-003 mutation controls do not interfere with:

- dirty Edit;
- Question mutation;
- authoring visibility;
- official assignment lock from FE-002.

No broad frontend suite.

---

# 99. Stage 6 Official Homework Regression

Because the Topic result-pair repository/data source is extended, run the
existing focused Stage 6 tests for:

```text
TeacherOfficialHomeworkController
TeacherTopicResultPairController
TeacherTopicResultPair DTO/data source
Homework detail official UX
```

Required:

- existing `setOfficialHomework` body stays exact;
- Stage 8 extension never clears existing Blitz;
- Homework replacement lock rules remain unchanged.

Do not weaken Stage 6 assertions.

---

# 100. Focused Verification Commands

Run from:

```text
frontend/
```

Use actual filenames where current implementation combines responsibilities.

Conceptually:

```bash
fvm flutter test \
  test/features/teacher/teacher_blitz_schedule_test.dart \
  test/features/teacher/teacher_blitz_lifecycle_data_source_test.dart \
  test/features/teacher/teacher_blitz_lifecycle_controller_test.dart \
  test/features/teacher/teacher_official_blitz_controller_test.dart \
  test/features/teacher/teacher_blitz_detail_screen_test.dart
```

Include updated Topic lifecycle integration test.

---

# 101. Direct Regression Verification

Run exact focused tests for:

- FE-002 Blitz Edit/Question authoring affected by route mutation serialization;
- FE-001 Blitz detail/list affected by authoritative refresh;
- existing Stage 6 Topic result-pair/official Homework;
- existing Topic lifecycle `topic_has_open_assessments`.

Do not run full frontend suite.

---

# 102. Focused Analyze

Run:

```bash
fvm flutter analyze --no-pub lib/features/teacher
```

If:

```text
lib/core/network/api_error_codes.dart
```

or core error parsing changes, include the narrowest supported analyze target.

No router change is expected; analyze router only if actually modified.

Do not silently substitute full-project analyze unless pinned CLI requires it.

---

# 103. Format Check

Run read-only format check on the actual changed Dart files and focused tests.

Conceptually:

```bash
fvm dart format --output=none --set-exit-if-changed \
  <changed lib files> \
  <changed test files>
```

Do not format unrelated code.

---

# 104. Git Diff Check

From repository root:

```bash
git diff --check
```

Required:

```text
PASS
```

Then perform focused scope/diff review.

Do not run:

- full frontend suite;
- full project analyze;
- Windows build;
- Android build;
- broad E2E.

Those belong to Frontend Phase 2 / Integration.

---

# 105. Acceptance Criteria — Schedule

- [ ] Schedule shown only for Draft.
- [ ] Reschedule shown only for Scheduled.
- [ ] No schedule control on Active/Closed/Archived.
- [ ] Institution timezone used.
- [ ] No device future-time authority.
- [ ] Schedule request exact.
- [ ] Scheduled same instant is local no-op.
- [ ] Draft same instant still performs lifecycle Schedule.
- [ ] UI clearly states Schedule does not auto-activate.
- [ ] Uncertain Schedule reconciles via GET.
- [ ] No automatic Schedule replay.

---

# 106. Acceptance Criteria — Official Blitz

- [ ] Existing result-pair read reused.
- [ ] No Blitz-only PUT when pair is null.
- [ ] UI guides Teacher to choose official Homework first.
- [ ] Only whole-group Draft/Scheduled candidate offered.
- [ ] Null Blitz side + unlocked pair can be filled.
- [ ] Null Blitz side + locked pair can still be filled.
- [ ] Existing other Blitz + unlocked pair can be replaced.
- [ ] Existing other Blitz + locked pair cannot be replaced.
- [ ] Already-current Blitz shows Official only.
- [ ] PUT always preserves current Homework ID.
- [ ] No clear/remove official operation.
- [ ] Uncertain PUT reconciles via pair GET.
- [ ] Existing Stage 6 Homework designation remains green.

---

# 107. Acceptance Criteria — Activate

- [ ] Activate available for Draft/Scheduled.
- [ ] Scheduled time does not gate manual Activate.
- [ ] Confirmation explains synchronized vs individual server snapshot.
- [ ] Required Idempotency-Key generated securely.
- [ ] One logical operation owns one key.
- [ ] Controller distinguishes fresh `initial_send` from explicit `same_key_retry`.
- [ ] Unknown outcome does not auto-replay.
- [ ] GET Active reconciles success.
- [ ] GET Draft/Scheduled offers explicit same-key Retry.
- [ ] Same-key Retry uses identical key.
- [ ] Fresh activation success requires current `status=active`.
- [ ] Completed same-key replay accepts current `active|closed|archived`.
- [ ] Closed/Archived replay requires persisted activation evidence and does not reopen.
- [ ] Same-key replay `draft|scheduled` is rejected as impossible successful activation.
- [ ] Valid Closed/Archived replay is confirmed success, not invalidResponse/uncertain.
- [ ] Institution setting error handled.
- [ ] scoreable-points error handled.
- [ ] assignment/cohort errors handled.
- [ ] success/replay refreshes detail/list/pair.
- [ ] no local countdown/monitor navigation.

---

# 108. Acceptance Criteria — Close / Archive

- [ ] Close only Active.
- [ ] Close confirmation explains server freezes in-progress work.
- [ ] Close has no Idempotency-Key.
- [ ] Uncertain Close reconciles via GET.
- [ ] Archive Closed available.
- [ ] Practice Draft/Scheduled Archive available only when client can safely
      establish non-official status.
- [ ] Official preactivation Archive hidden.
- [ ] Unconfirmed group official status hides preactivation Archive.
- [ ] Archive no auto replay.
- [ ] Terminal lifecycle adopted from server.

---

# 109. Acceptance Criteria — Integration / Safety

- [ ] Same-Blitz mutations serialized in current client.
- [ ] FE-002 metadata/Question mutation remains functional.
- [ ] Session/route stale completion ignored.
- [ ] Confirmation dialog stale completion cannot mutate.
- [ ] No optimistic lifecycle/pair state.
- [ ] Backend machine codes drive branching.
- [ ] Topic open-assessment copy includes Homework and Blitz.
- [ ] Topic conflict refresh includes Blitz list.
- [ ] Mobile remains read-only for FE-003 controls.
- [ ] No monitoring/exception UI.

---

# 110. Scope Acceptance

- [ ] No new Flutter route.
- [ ] No Builder duplication.
- [ ] No Student Blitz UI.
- [ ] No monitoring.
- [ ] No attempt-exception grant.
- [ ] No checking/scoring/result UI.
- [ ] No automatic activation.
- [ ] No mobile lifecycle mutation.
- [ ] No backend changes.
- [ ] No package/platform changes.
- [ ] Focused tests pass.
- [ ] FE-001/002 regressions pass.
- [ ] Stage 6 result-pair/Homework regressions pass.
- [ ] Topic lifecycle regression passes.
- [ ] Focused analyze passes.
- [ ] Format check passes.
- [ ] `git diff --check` passes.

---

# 111. Focused Diff Self-Check

Before completion confirm the diff implements only:

```text
Schedule/Reschedule
+
Official Blitz designation
+
Activate/Close/Archive
+
required Topic open-assessment integration
```

Verify specifically:

```text
no auto-activation
no timer setting editor
no monitoring
no exception grant
no Student execution
no mobile lifecycle controls
locked partial pair remains fillable
activation same-key Retry preserved
activation replay after later Close/Archive accepted without reopening
official preactivation archive safety
```

Confirm every changed file is necessary.

---

# 112. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. Schedule/Reschedule UX and time-authority behavior;
4. result-pair repository extension and official-Blitz state matrix;
5. locked partial pair behavior;
6. activation Idempotency-Key lifecycle;
7. activation fresh-success vs same-key replay validation, including later Close/Archive;
8. Close/Archive behavior;
9. same-route mutation serialization;
10. Topic open-assessment integration correction;
11. desktop/mobile capability boundary;
12. focused new test results;
13. FE-001/002 regression results;
14. Stage 6 official Homework/result-pair regression results;
15. Topic lifecycle regression result;
16. focused analyze result;
17. format check result;
18. `git diff --check`;
19. final `git status --short`;
20. focused scope/diff self-check;
21. any blocker/deviation.

Do not claim Stage 8 frontend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-FE-004` remains blocked until:

```text
S08-FE-003 = Accepted / Delivered
```

---

# 113. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Schedule/Reschedule API              = RESOLVED
Schedule timezone/input              = RESOLVED
No auto-activation boundary          = RESOLVED
Official Blitz result-pair API       = RESOLVED
No-pair Homework prerequisite        = RESOLVED
Locked partial pair fill             = RESOLVED
Unlocked replacement                 = RESOLVED
Official archive safety              = RESOLVED
Activation availability              = RESOLVED
Activation Idempotency-Key           = RESOLVED
Activation unknown/retry behavior    = RESOLVED
Activation replay current lifecycle  = RESOLVED
Activation error UX                  = RESOLVED
Close behavior                       = RESOLVED
Archive behavior                     = RESOLVED
Mutation reconciliation              = RESOLVED
Same-route serialization             = RESOLVED
Topic open-assessment integration    = RESOLVED
Desktop/mobile boundary              = RESOLVED
Session/stale-completion safety      = RESOLVED
Accessibility                        = RESOLVED
Focused tests                        = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-FE-002 Accepted / Delivered
Next task after acceptance            = S08-FE-004
```
