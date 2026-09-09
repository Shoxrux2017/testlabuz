# Phase 2 Read-Only Block Review Contract — Stage 7 Frontend

## 1. Review Metadata

| Field | Value |
|---|---|
| Review ID | `S07-FE-PHASE-2` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Block | `Frontend` |
| Status | `Pending — execute only after S07-FE-001…005 are Accepted and Delivered` |
| Review mode | `Read-only` |
| Depends on | `S07-BE-PHASE-2 = PASS`; `S07-FE-001…005 = Accepted / Delivered` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Audited `origin/main` | `Resolve at checkpoint execution time` |
| Frontend implementation base | `Resolve as the commit immediately before the first delivered S07-FE-001 production change` |
| Flutter toolchain | `Repository-pinned FVM Flutter 3.44.7 unless current main changes it legitimately before execution` |
| Review owner | `ChatGPT` |
| Verification executor | `Project Owner or approved CI` |
| Codex role | `None during read-only review; focused fixes only if ChatGPT later issues a fix contract` |
| Verdict | `Pending` |
| Findings | `Pending` |
| Next permitted gate on PASS | `S07-INT-001 — Real-Stack Student Homework E2E, after mandatory Integration Harness Preflight` |
| Next permitted gate on findings | `Focused Frontend Phase 2 fix contract(s) only` |

This is a **review/checkpoint contract**, not an implementation task.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Purpose

Perform the mandatory Stage 7 Frontend Phase 2 checkpoint after:

```text
S07-FE-001
S07-FE-002
S07-FE-003
S07-FE-004
S07-FE-005
```

have all been implemented, focused-verified, delivered to `origin/main`, and accepted.

The checkpoint reviews the complete Student Homework execution frontend as one integrated Flutter surface.

Primary review areas:

- feature-first architecture;
- strict Student-safe API/DTO contract;
- Student session ownership;
- stale async completion safety;
- canonical GoRouter hierarchy;
- Homework list/detail read UX;
- Attempt Start/Resume;
- client idempotency-key generation;
- same-key uncertain Start retry;
- Attempt read shell;
- eight non-file answer editors;
- explicit per-Question Save semantics;
- uncertain answer mutation reconciliation;
- file picker/upload/replace;
- uncertain file upload handling;
- protected Student submission Open/Save As;
- unsaved-work navigation guards;
- final Submit readiness/confirmation;
- same-key uncertain Submit retry;
- route-level Submit operation gate;
- deadline/Teacher-close terminal reconciliation;
- desktop/mobile behavior;
- accessibility/responsiveness;
- previous Stage 1–6 regression safety;
- full frontend tests/static/format/build verification.

---

# 3. Entry Gate

Do not execute this checkpoint until:

```text
Stage 7 Backend Phase 2 = PASS

S07-FE-001 = Accepted / Delivered
S07-FE-002 = Accepted / Delivered
S07-FE-003 = Accepted / Delivered
S07-FE-004 = Accepted / Delivered
S07-FE-005 = Accepted / Delivered
```

Before review:

1. switch to `main`;
2. fetch/prune `origin`;
3. confirm local `main == origin/main`;
4. confirm ahead/behind `0/0`;
5. confirm clean worktree;
6. freeze final current `origin/main` SHA;
7. identify the Stage 7 frontend implementation base;
8. confirm repository FVM pin;
9. confirm Stage 7 Backend Phase 2 PASS evidence remains valid.

Required Git evidence:

```text
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Expected:

```text
branch = main
HEAD == origin/main
ahead/behind = 0/0
working tree clean
```

If the frontend block is partial, uncommitted, divergent, or missing an accepted delivery:

```text
BLOCKED
```

Do not audit an uncommitted task branch as the Stage frontend checkpoint.

---

# 4. Determining the Frontend Implementation Base

At execution time identify the commit immediately before the first Stage 7 frontend **production implementation** entered `main`.

Preferred audited range:

```text
<stage7_frontend_implementation_base>...origin/main
```

The range must include:

- all FE-001…005 production changes;
- all FE-001…005 focused tests;
- all Stage 7 frontend Phase 2 fixes merged before final PASS;
- shared frontend infrastructure changes required by Stage 7;
- route changes;
- `LocalFileActions` compatibility changes;
- any legitimate tooling/config change materially affecting verification.

Task-contract/bookkeeping-only commits may be present but should be distinguished from application changes.

Do not omit any intermediate Stage 7 frontend delivery.

---

# 5. Read-Only Rule

Phase 2 execution is strictly read-only.

Allowed:

- inspect source/tests/routes/domain/data/application/presentation;
- inspect Git diff/history;
- run tests;
- run static analysis;
- run read-only format check;
- run required target debug builds;
- inspect generated build results;
- report findings.

Forbidden:

- edit production code;
- edit tests;
- auto-format;
- auto-fix analyzer output;
- change dependencies;
- change FVM pin;
- stage;
- commit;
- push;
- open/merge a fix PR;
- modify task/checkpoint bookkeeping during the review execution.

If a finding is discovered:

```text
record finding
assign severity
Verdict = NOT ACCEPTED
```

Fixes happen only through a separate focused implementation contract.

---

# 6. Severity Model

Use exactly:

## P1 — Critical

Examples:

- Student sees answer keys/correctness data;
- cross-Tenant or another Student's Homework/Attempt/file becomes visible;
- stale async completion publishes another Student/session/route target;
- same-key idempotency retry is replaced with a new key and can create duplicate state;
- Submit freezes a different local/server state than the Student was shown;
- Student can mutate a terminal Attempt because frontend lifecycle reconciliation is broken;
- private file handling exposes public/storage path;
- unsafe route bypass exposes another protected role surface.

Any P1:

```text
NOT ACCEPTED
```

Integration prohibited.

## P2 — Major

Examples:

- one of the eight non-file editors sends wrong payload;
- file upload sends wrong multipart contract;
- Start 200 resume race treated as failure;
- timeout retry creates a new idempotency key;
- Submit allowed while unsaved/uncertain local work exists;
- Submit incorrectly requires all Questions answered;
- GET Attempt hierarchy validation is missing;
- device time controls authoritative eligibility;
- terminal Attempt still allows editing;
- file uncertain state is falsely confirmed from metadata-only GET;
- route-leave protection loses meaningful local work;
- full test/analyze/build regression;
- mobile/desktop route behavior is broken;
- substantial accessibility dead-end.

Any P2:

```text
NOT ACCEPTED
```

Integration prohibited.

## P3 — Minor but actionable

Examples:

- localized status wording inconsistency;
- small test maintainability gap;
- minor redundant request churn;
- small accessibility label defect;
- maintainability issue with concrete future risk.

Default final PASS target:

```text
P1 = 0
P2 = 0
P3 = 0
```

If a truly non-blocking P3 is intentionally deferred, ChatGPT must explicitly justify it. Do not silently carry findings.

---

# 7. Audited Task Map

At execution, record final delivery evidence.

| Task | Responsibility | Delivery evidence | Result |
|---|---|---|---|
| `S07-FE-001` | Student Homework read foundation | `<PR/SHA>` | Pending |
| `S07-FE-002` | Attempt Start/Resume shell | `<PR/SHA>` | Pending |
| `S07-FE-003` | Eight non-file answer editors | `<PR/SHA>` | Pending |
| `S07-FE-004` | File answer UX | `<PR/SHA>` | Pending |
| `S07-FE-005` | Submit/finalization UX | `<PR/SHA>` | Pending |

Verify every accepted task commit is an ancestor of audited `origin/main`.

Confirm no hidden frontend Stage 7 scope entered outside an approved task/fix.

---

# 8. Mandatory Full Frontend Test Suite

Run one initial full suite:

```bash
cd frontend
fvm flutter test
```

Record:

- exit code;
- total passed;
- total failed;
- skipped if reported;
- duration if reported.

Do not hide an initial failure.

If it fails:

1. preserve first-run evidence;
2. identify failing tests;
3. use narrow diagnostics only;
4. classify:
   - candidate production defect;
   - deterministic test defect;
   - environment/tooling failure;
   - pre-existing unrelated failure;
5. do not repeatedly run the full suite until it happens to pass.

Any unresolved deterministic failure:

```text
NOT ACCEPTED
```

If a later production/test fix is delivered and materially changes the frontend head, ChatGPT decides whether a new full-suite run is required. A previously failing full suite must eventually pass.

---

# 9. Mandatory Static Analysis

Run:

```bash
cd frontend
fvm flutter analyze --no-pub
```

Required:

```text
No issues found
```

Record exact exit code/result.

Do not auto-fix analyzer findings during review.

---

# 10. Mandatory Full Frontend Format Verification

Run read-only:

```bash
cd frontend
fvm dart format --output=none --set-exit-if-changed lib test integration_test
```

If current repository policy includes more Dart directories, include them.

Required:

```text
zero files changed
exit code 0
```

Do not run write-format mode.

---

# 11. Mandatory Windows Debug Build

Run:

```bash
cd frontend
fvm flutter build windows --debug
```

Required:

```text
PASS
```

Record final artifact path if reported.

If the execution environment cannot perform a Windows build:

```text
environment blocker
```

Do not silently skip it.

Project Owner must execute it in an approved Windows environment before PASS.

Application/compiler failure:

```text
NOT ACCEPTED
```

---

# 12. Mandatory Android Debug Build

Run:

```bash
cd frontend
fvm flutter build apk --debug
```

Required:

```text
PASS
```

Record artifact path if reported.

If Gradle/cache/tooling failure is clearly environment-specific:

- classify separately;
- do not change product code merely to bypass workstation tooling;
- final PASS still requires a valid Android debug build.

---

# 13. Stage-Wide Diff Hygiene

Run:

```bash
git diff --check <stage7_frontend_implementation_base>...origin/main
```

Required:

```text
PASS
```

Inspect:

```bash
git diff --stat <stage7_frontend_implementation_base>...origin/main
git diff --name-status <stage7_frontend_implementation_base>...origin/main
```

Confirm:

- no backend production code entered the frontend block unexpectedly;
- no unrelated Teacher/Institution/Parent changes beyond justified shared regression work;
- no new dependency/package;
- no accidental `pubspec.lock` change;
- no unexpected platform change;
- no generated junk/build artifacts;
- no secrets/debug output;
- no broad unrelated formatting churn;
- no weakened test assertions.

---

# 14. Architecture Review

Expected flow remains:

```text
Presentation
-> Application / Riverpod Controller
-> Repository contract
-> Repository implementation
-> Remote data source / DTO
-> configured Dio
```

PASS requires:

- Widgets do not call Dio;
- Widgets do not parse raw JSON;
- Controllers do not build raw API URLs;
- DTOs own strict transport parsing;
- repositories expose typed operations;
- no second router;
- no second HTTP client;
- no second state framework;
- no global mutable Homework/Attempt cache;
- no generic Assessment framework introduced speculatively;
- `StudentSessionKey` remains the session-ownership basis;
- one canonical Student Homework/Attempt domain exists;
- one canonical saved Student submission domain exists;
- shared protected download stack is reused, not duplicated.

---

# 15. Domain / DTO Strictness Review

Audit all Stage 7 frontend DTOs.

Verify exact parsing for:

```text
Student Homework list/detail
Student safe Question projection
Attempt read
saved answers
answer mutation response
file mutation response
Submit response
```

Required:

- exact keys;
- canonical UUIDs;
- strict enums;
- UTC timestamps;
- finite numeric parsing;
- attempt policy invariants;
- Answer-to-Question cross-reference validation;
- file metadata constraints;
- malformed success => `invalidResponse`.

No raw transport map may become application/presentation authority.

---

# 16. Student Question Privacy Review

This is a blocking security surface.

Search the complete Student Stage 7 frontend for prohibited fields:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
configuration
client_key
```

Verify Student DTOs reject them.

Verify presentation/domain never exposes or derives:

- correct choice;
- correct True/False;
- accepted written answers;
- correct matching;
- correct ordering;
- fill accepted answers.

Multiple Choice:

```text
max_selections
```

may be shown.

It must not reveal which options are correct.

Any answer-key leak:

```text
P1
```

---

# 17. Homework Read Surface Review

Verify FE-001:

- Homework section is independent from Topic detail read state;
- Topic detail still works if Homework list fails;
- Homework list uses backend `topic_id`;
- status filter works;
- pagination is server-authoritative;
- no client search/sort behavior outside contract;
- detail route is canonical;
- Homework status/my-status/attempt counts come from backend;
- no score displayed;
- `score_visible=false` enforced;
- deadline formatting uses Institution timezone;
- device time does not recalculate remaining attempts.

---

# 18. Student Router Review

Expected Stage 7 Student routes:

```text
/student

/student/topics/:topicId

/student/topics/:topicId/homework/:homeworkId

/student/topics/:topicId/homework/:homeworkId/attempts/:attemptId
```

Verify:

- no competing flat frontend Attempt route;
- all UUID path parsers are exact;
- extra segments rejected;
- direct entry is guarded;
- Student desktop/mobile both supported;
- Topic ID extraction works at nested Homework/Attempt routes;
- Homework ID extraction works at Attempt route;
- Attempt ID extraction works only at Attempt route;
- wrong/ineligible session cannot transiently render protected Student content;
- Teacher/Institution Admin/Parent routing remains unchanged.

---

# 19. Student Session / Stale Async Review

Audit every Stage 7 Student controller.

Expected ownership factors where relevant:

```text
StudentSessionKey
Topic ID
Homework route target
Attempt route target
Question ID
File ID
operation generation
read generation
active mutation identity
idempotency logical operation identity
```

Verify stale completion cannot:

- overwrite another Student's Homework;
- overwrite another Attempt;
- publish after logout;
- publish across Institution switch;
- navigate after target change;
- show stale SnackBar;
- apply a stale answer save;
- apply a stale file upload;
- open/save an old file after replacement;
- adopt a Submit result into a newer route/session.

`context.mounted` alone is insufficient for controller-owned async work.

---

# 20. Idempotency Key Generator Review

Audit the FE-002 shared generator.

Required:

```text
Random.secure()
16 random bytes
RFC 4122 version 4 bits
RFC variant bits
lowercase canonical UUID
```

No:

- timestamp-derived keys;
- predictable `Random()`;
- user/Institution data in key;
- dependency addition merely for UUID.

Verify injected deterministic generator support for tests.

---

# 21. Attempt Start / Resume Review

Verify FE-002 exact behavior.

## Confirmed existing in-progress Attempt

```text
Resume
-> direct navigation
-> no Start POST
```

## New Start

```text
POST /student/homework/{homework}/attempts
Idempotency-Key
{}
```

Map:

```text
201 = created
200 = backend race-resume
```

Both success cases navigate to returned Attempt.

No optimistic:

```text
used++
remaining--
```

---

# 22. Start Uncertain Outcome Review

Critical reliability rule:

```text
timeout/connection/unknown/invalid success/5xx
=> retain SAME Idempotency-Key
```

Retry:

```text
same Homework
same key
same body
```

No new key.

Deterministic 4xx:

```text
key discarded
```

No automatic new-key retry.

Verify:

- duplicate taps suppressed;
- stale session/target clears ownership;
- same-key retry tests exist;
- 200 resume race is not treated as conflict.

---

# 23. Attempt Read / Hierarchy Review

GET:

```text
/student/attempts/{attempt}
```

Verify strict hierarchy composition:

```text
route topicId
-> Homework detail confirms topicId/homeworkId

route attemptId
-> Attempt confirms assessmentId == homeworkId
```

Frontend route hierarchy mismatch must not render a valid resource under a wrong parent path.

Backend remains authorization authority.

No extra authorization endpoint is invented.

---

# 24. Saved Answer DTO Review

Verify FE-002 saved-answer parsing for:

```text
single_choice
multiple_choice
true_false
short_written
open_written
matching
ordering
fill_in_blank
file_based
```

Cross-collection checks:

- choice option IDs belong to Question;
- matching IDs belong to left/right safe sets;
- ordering IDs belong to safe items;
- fill IDs belong to safe blanks;
- answer type matches Question type;
- no duplicate saved answer per Question.

No checking/score fields.

---

# 25. Eight Non-File Editor Review

Verify FE-003 editors exactly:

```text
single_choice
multiple_choice
true_false
short_written
open_written
matching
ordering
fill_in_blank
```

`file_based` must not be edited by FE-003 logic.

Review type-specific controls, payloads, local validation and clear behavior.

---

# 26. Explicit Save Review

Locked Stage 7 frontend behavior:

```text
per-Question explicit Save
no autosave
```

Verify:

- Save disabled when semantic no-op;
- dirty state compares semantic canonical answer vs confirmed server answer;
- no debounce/timer autosave;
- no route-pop autosave;
- server mutation response becomes confirmed base;
- parent Attempt refresh is reconciliation only.

---

# 27. Non-File Clear Semantics Review

Clearable:

```text
multiple_choice
short_written
open_written
matching
ordering
fill_in_blank
```

Not clearable:

```text
single_choice
true_false
file_based
```

Verify Clear:

```text
changes local draft only
```

and Student still presses Save.

Absent server answer + empty local canonical draft:

```text
no request
```

---

# 28. Multiple Choice Review

Verify:

- backend `maxSelections` controls local cap;
- selected options can always be deselected;
- unselected options disable at cap;
- frontend never infers which are correct;
- `selection_limit_exceeded` refreshes/reconciles;
- Student selections are not silently dropped.

---

# 29. Matching Review

Verify:

- no left/right index pairing;
- backend order is presentation order only;
- Student explicit mapping state;
- unique right selection enforced;
- partial mapping supported;
- no `match_key`;
- no correctness coloring.

---

# 30. Ordering Review

Verify:

- partial ordering supported;
- `Unassigned` exists;
- submitted positions are unique;
- no implicit swap unless contract intentionally implements explicit Student choice;
- no correct-position data;
- initial backend item order is not labeled correct.

---

# 31. Written / Fill Review

Short Written:

```text
max 1000 Unicode scalars
exact text preserved
no scoring normalization
```

Open Written:

```text
max 20000 Unicode scalars
exact text preserved
```

Fill:

```text
partial
max 1000 Unicode scalars per non-empty value
whitespace-only omitted
non-empty exact text preserved
```

Verify no lowercase/apostrophe/whitespace scoring normalization is implemented in Flutter.

---

# 32. Non-File Mutation Uncertainty Review

PUT answer has no idempotency key.

Verify uncertain result:

```text
connection
timeout
cancelled
invalidResponse
unknown
5xx/unknown server
```

retains the exact canonical mutation snapshot.

Retry:

```text
same attempt
same question
same payload
```

GET reconciliation:

- exact server answer equal to pending mutation => confirmed saved;
- different + in-progress => pending attempted value becomes dirty local draft;
- terminal => server state wins.

No false success.

---

# 33. One Active Non-File Save Review

Verify FE-003 permits at most:

```text
one active answer save/uncertain operation per Attempt
```

Other drafts may remain editable.

No second save request starts.

This keeps server Attempt-row serialization and client state coherent.

---

# 34. File Picker / Local Validation Review

Verify FE-004:

- existing `file_picker` reused;
- no new package;
- safe extensions come from Question;
- picker cancel is neutral;
- extension revalidated after pick;
- `length > 0`;
- `length <= max_size_bytes`;
- filename validated;
- no local binary signature parser;
- no local MIME authority.

Backend remains authoritative for content inspection.

---

# 35. File Upload Transport Review

Exact:

```text
PUT /student/attempts/{attempt}/answers/{question}

multipart:
  type = file_based
  file = streamed selected file
```

Verify:

- no query;
- no Idempotency-Key;
- filename preserved;
- no public/storage path;
- upload progress is transport-only, not success proof.

---

# 36. File Replacement Review

Verify:

- first upload works;
- replacement works;
- confirmed replacement preserves server File ID;
- current saved file is distinct from selected replacement;
- no file clear/delete UI;
- local selected file has no server ID before success.

No metadata-only client no-op detection.

---

# 37. File Upload Uncertainty Review

This is a major Stage 7 reliability surface.

Verify:

```text
timeout/connection/unknown/invalid success
=> selected file retained
=> outcome uncertain
```

Retry:

```text
same selected file
same target
```

A GET Attempt showing same:

```text
filename
size
extension
```

must **not** automatically prove exact bytes committed.

The only in-place confirmation is:

```text
Retry upload -> valid 200
```

or later user re-enters and treats the server state as current without claiming the earlier uncertain operation specifically succeeded.

No false exact-byte inference.

---

# 38. Deterministic File Failure Review

Verify:

```text
unsupported_file_type
file_too_large
file_upload_failed
deadline_passed
attempt_not_editable
task_closed
task_archived
business_conflict
```

are handled with the contracted confirmed/uncertain distinctions.

Specifically:

```text
file_upload_failed
```

is a confirmed storage failure and may retry the same local selected file.

No false success.

---

# 39. Protected Student Submission Download Review

Verify saved Student submission:

```text
GET /files/{fileId}/download
```

uses existing:

```text
ProtectedLearningMaterialTransfer
```

rather than a duplicate transport.

Shared protected parser must still enforce:

- status 200;
- canonical supported Content-Type;
- attachment Content-Disposition;
- `Cache-Control: private, no-store`;
- `X-Content-Type-Options: nosniff`;
- non-empty bytes;
- bounded bytes.

---

# 40. Submission Download Metadata Check

Before local Open/Save As verify Stage 7 controller cross-checks:

```text
downloaded.extension == serverFile.extension
downloaded.bytes.length == serverFile.sizeBytes
downloaded size <= Student 15 MB hard max
```

If mismatch:

```text
no local Open/Save
invalid protected response
```

Filename may use sanitized server Content-Disposition fallback.

No storage path/checksum exposure.

---

# 41. `LocalFileActions` Compatibility Review

Stage 7 FE-004 may minimally extend Save As dialog-title support.

Verify:

- old Learning Material callers still default to:
  ```text
  Save learning material
  ```
- Student submission uses:
  ```text
  Save submitted answer
  ```
- local Open behavior remains unchanged;
- Stage 5 file-transfer tests remain green;
- no broad shared file refactor entered the task.

---

# 42. Unsaved Work Navigation Guard Review

Verify route-leave priorities compose across FE-003/004/005.

Expected priority:

```text
1. submitting
2. submit uncertain
3. answer/file mutation uncertain
4. dirty non-file / selected local file
5. clean leave
```

No stacked multiple dialogs for one Back action.

No automatic save/upload/submit on leave.

Clean/terminal route leaves normally.

---

# 43. Submit Readiness Review

Submit may run only when:

```text
Attempt confirmed in_progress
Attempt not refreshing
no dirty non-file drafts
no non-file save active
no non-file uncertain save
no pending selected file
no file picker/upload active
no file uncertain upload
route operation gate idle
```

Verify Submit is **not** blocked merely because Questions are unanswered.

Zero-answer Attempt:

```text
must remain submittable
```

when locally clean.

---

# 44. Confirmed Answer Count Review

Confirmation shows:

```text
questionCount
confirmedAnsweredCount
unansweredCount
```

Count must merge latest confirmed:

- Attempt GET answers;
- FE-003 confirmed answer mutation results;
- FE-004 confirmed file results.

Do not count:

- dirty drafts;
- selected but unuploaded file;
- uncertain mutation snapshot.

No fake completeness rule.

---

# 45. Submit Confirmation Review

Verify confirmation:

```text
Submit Attempt N?
```

shows:

- saved answer count;
- unanswered count;
- Attempt becomes locked/read-only;
- unanswered Questions are allowed;
- later next Attempt, if any, is separate.

No:

```text
Save all and submit
```

action.

After dialog returns true, session/target/readiness are rechecked before request.

---

# 46. Submit Transport Review

Exact:

```text
POST /student/attempts/{attempt}/submit
Idempotency-Key: UUID
body = {}
no query
```

Success:

```text
200
```

Strict response:

```text
data
message
```

Attempt parser reused.

No duplicate Submit DTO lifecycle parser.

---

# 47. Submit Idempotency Review

Critical reliability rule:

```text
one key per logical Submit
```

Uncertain outcome:

```text
retain same key
```

Retry:

```text
same Attempt
same key
same body
```

Deterministic 4xx:

```text
key discarded
```

No automatic new-key retry.

No duplicate submit call while submitting/uncertain.

---

# 48. Submit Route Operation Gate Review

Verify FE-005 synchronously claims:

```text
submitting
```

before first async wait/request after final readiness check.

FE-003 and FE-004 mutation controllers must refuse new:

- answer Save;
- file picker/upload/retry;

when gate is:

```text
submitting
submitUncertain
```

This must exist in application logic, not only disabled Widgets.

---

# 49. Submit Uncertain Outcome Review

Uncertain:

```text
connection
timeout
cancelled
invalidResponse
unknown
5xx/unknown server
```

Required state:

```text
submitUncertain
same key retained
editors frozen
```

Actions:

```text
Retry submission
Check current Attempt
```

No normal Submit/new key.

---

# 50. Check Current Attempt Review

During uncertain Submit:

## GET terminal `student_submit`

Desired explicit Submit outcome is confirmed.

## GET terminal deadline/close

Authoritative auto-finalization is accepted.

Do not show explicit Submit success.

## GET still in_progress

Uncertainty remains.

Do not conclude failure.

Same key remains for Retry.

---

# 51. Submit Success Adoption Review

On valid 200:

- returned Attempt hierarchy checked;
- returned Attempt is terminal, not `in_progress`;
- current Attempt controller adopts authoritative returned Attempt immediately;
- editors become terminal/read-only immediately;
- pending local editor/file state reconciles;
- Homework detail/list invalidated or marked stale;
- no optimistic local attempt-count patch.

No forced immediate navigation away.

---

# 52. Deadline / Teacher Close UX Reconciliation

Verify frontend responds safely to backend authoritative finalization.

Expected terminal labels:

```text
student_submit
  -> Submitted by you

homework_deadline_auto_submit
  -> Finalized at the Homework deadline

task_closed_auto_finalize
  -> Finalized when the Homework was closed
```

No score/checking.

No local rewrite of finalization timestamp/reason.

---

# 53. Terminal Attempt Review

For:

```text
submitted
waiting_for_teacher_review
checked
```

the Stage 7 frontend remains read-only.

No:

- answer editors;
- file picker/upload;
- Submit;
- local score rendering.

Saved file Open/Save As may remain available.

---

# 54. Next Attempt Review

After Submit:

- FE-005 terminal screen does not start next Attempt;
- Student returns to Homework detail;
- refreshed backend:
  ```text
  remaining
  in_progress_attempt
  status
  ```
  controls FE-002 Start/Resume visibility.

No client decrement/next-number calculation.

---

# 55. Backend Authority Review

Search Stage 7 frontend for client-side authoritative business logic that should not exist.

Forbidden frontend authority includes:

```text
DateTime.now() >= deadline => deny action
remaining = 3 - used
all Questions must be answered
score calculation
checking decision
official Attempt selection
finalization timestamp creation
finalization reason creation
ownership/tenant authorization
```

Presentation formatting is allowed.

Backend rejection always overrides local assumptions.

---

# 56. API Failure Mapping Review

Verify application branching uses stable:

```text
ApiErrorCodes
ApiFailure.kind
statusCode
```

not human messages.

Relevant codes across Stage 7 include:

```text
resource_not_found
task_not_active
task_closed
task_archived
assessment_not_assigned
deadline_passed
attempts_exhausted
attempt_not_editable
selection_limit_exceeded
idempotency_key_reused
business_conflict
unsupported_file_type
file_too_large
file_upload_failed
file_not_available
validation_failed
```

No raw URL/token/SQL/server exception shown.

---

# 57. Mutation Uncertainty Model Consistency Review

Review three independent mutation categories:

## Start

High-risk idempotent POST.

```text
uncertain => retry same Idempotency-Key
```

## Answer/file PUT

No idempotency key.

```text
uncertain => retry same semantic payload/file
```

with operation-specific reconciliation.

## Submit

High-risk idempotent POST.

```text
uncertain => retry same Idempotency-Key
```

Verify no controller accidentally shares the wrong uncertainty strategy.

---

# 58. State/Provider Dependency Review

Audit Riverpod dependency graph for:

- provider cycles;
- broad invalidation loops;
- Submit gate cycles;
- editor/Attempt refresh loops;
- file-transfer/Attempt refresh loops;
- stale listener feedback loops.

Required:

- narrow dependencies;
- no God provider;
- no global mutable operation singleton;
- route target family keys remain explicit.

---

# 59. Controller Responsibility Review

Expected focused ownership:

```text
Homework list controller
Homework detail controller
Attempt Start controller
Attempt read controller
Answer editor controller
File answer controller
Submission transfer controller
Submit controller
Route operation gate
```

Flag if one controller has absorbed unrelated responsibilities such as:

```text
routing + HTTP + DTO parsing + storage + scoring
```

Material responsibility collapse:

```text
P2
```

---

# 60. Cache / Invalidation Review

Verify:

- no repository cache added;
- Riverpod owns current UI state;
- Homework 404 invalidates Topic Homework list;
- Start success invalidates Homework read state;
- answer save refreshes Attempt only;
- file upload refreshes Attempt only;
- Submit invalidates Homework detail/list;
- no optimistic list pagination/count mutation.

Avoid broad unrelated Student feature invalidation.

---

# 61. Desktop / Mobile Capability Review

Stage 7 Student execution must support:

```text
desktop
mobile
```

Verify both can:

- read Homework;
- Start/Resume;
- open Attempt;
- edit eight non-file answers;
- file upload/replace;
- Submit;
- Open/Save saved Student submission if native capability permits.

Do not introduce Teacher-like desktop-only Student authoring restrictions.

---

# 62. Responsive Layout Review

Check narrow/mobile and wider/desktop layouts.

Verify no horizontal overflow for:

- long Homework title;
- long Question prompt;
- Multiple Choice options;
- Matching rows;
- Ordering rows;
- Fill Blank fields;
- file names;
- Submit blocker/confirmation text.

Action buttons should wrap where necessary.

Text scaling must remain usable.

---

# 63. Accessibility Review

Verify meaningful support for:

- semantic headings;
- loading/progress labels;
- status text not color-only;
- Choice selection semantics;
- Multiple selected count;
- Matching dropdown labels;
- Ordering position labels;
- Fill field labels;
- Save/Discard/Clear labels;
- file picker/upload progress;
- Open/Save As;
- uncertain operation warnings;
- Submit confirmation;
- safe initial confirmation focus;
- keyboard navigation on desktop;
- touch targets on mobile;
- no focus traps.

Material accessibility dead-end:

```text
P2
```

---

# 64. Previous Stage Regression — Student Topics / Materials

Verify Stage 5 Student behavior remains intact:

- Student Topic list/detail;
- learning materials;
- protected Learning Material Open/Save As;
- existing Student session behavior;
- route guards.

Homework section must not break Topic/material failure isolation.

---

# 65. Previous Stage Regression — Teacher Homework

Stage 7 frontend should not materially alter Teacher Stage 6 behavior except minimal shared file infrastructure compatibility.

Verify:

- Teacher routes;
- Homework read/create/edit;
- Question Builder;
- lifecycle/official designation;
- Teacher protected Learning Material transfer;
- mobile read vs desktop authoring boundaries.

No Student Stage 7 shared change should break Teacher UI.

---

# 66. Shared File Regression

Because FE-004 touches `LocalFileActions`, verify:

```text
ProtectedLearningMaterialTransfer tests
Student Stage 5 topic transfer tests
Teacher material transfer tests
```

remain green.

Learning Material Save As still uses:

```text
Save learning material
```

Student submission Save As uses:

```text
Save submitted answer
```

No MIME/header regression.

---

# 67. No New Dependency / Platform Review

Inspect:

```text
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/android
frontend/windows
frontend/ios
frontend/linux
frontend/macos
frontend/web
```

Stage 7 should not require:

- UUID package;
- upload package;
- router package change;
- platform edit.

Any unapproved change is blocking until justified.

---

# 68. Stage 7 Frontend Acceptance-Criteria Matrix

Populate during execution.

| Criterion | Primary task(s) | Evidence | Result |
|---|---|---|---|
| Student Homework Topic section | FE-001 | `<tests/code>` | Pending |
| Safe Student Question DTOs | FE-001 | `<tests/code>` | Pending |
| Canonical Homework detail route | FE-001 | `<tests/router>` | Pending |
| Start create/resume UX | FE-002 | `<tests>` | Pending |
| Secure UUID v4 generator | FE-002 | `<tests>` | Pending |
| Same-key uncertain Start retry | FE-002 | `<tests>` | Pending |
| Canonical Attempt route | FE-002 | `<tests/router>` | Pending |
| Strict Attempt/saved-answer read | FE-002 | `<tests>` | Pending |
| Eight non-file editors | FE-003 | `<tests>` | Pending |
| Semantic no-op/clear | FE-003 | `<tests>` | Pending |
| Uncertain answer save reconciliation | FE-003 | `<tests>` | Pending |
| Unsaved draft leave guard | FE-003 | `<tests>` | Pending |
| File picker/local validation | FE-004 | `<tests>` | Pending |
| Multipart upload/replacement | FE-004 | `<tests>` | Pending |
| Uncertain file upload handling | FE-004 | `<tests>` | Pending |
| Own protected submission Open/Save As | FE-004 | `<tests>` | Pending |
| Submit readiness/confirmation | FE-005 | `<tests>` | Pending |
| Zero-answer Submit allowed | FE-005 | `<tests>` | Pending |
| Same-key uncertain Submit retry | FE-005 | `<tests>` | Pending |
| Submit route operation gate | FE-005 | `<tests>` | Pending |
| Deadline/close terminal reconciliation | FE-005 | `<tests>` | Pending |
| Desktop/mobile support | FE-001…005 | `<tests>` | Pending |
| No score/checking UI | FE-001…005 | `<review/tests>` | Pending |

No required row may remain `Not verified` for PASS.

---

# 69. Stage-Specific Security / Privacy Evidence

Confirm focused tests/evidence cover:

```text
Teacher correctness fields rejected
wrong Student/foreign Attempt 404 handling
resource-not-found reconciliation
session switch stale completion
another file ID cannot be acted on as current
protected download requires current saved file target
wrong role Student route gating
inactive user/Institution session reconciliation
password-change-required reconciliation
```

Frontend is not backend authorization, but it must not accidentally reuse stale/foreign identifiers after server denial.

---

# 70. Mandatory Idempotency Evidence

Confirm tests prove:

## Start

```text
timeout -> same key retry
5xx -> same key retry
201 create
200 resume
```

## Submit

```text
timeout -> same key retry
invalid success -> same key retained
Check current student_submit terminal -> confirmed
Check current in_progress -> remains uncertain
```

No new key is generated automatically in either uncertain flow.

---

# 71. Mandatory Local Mutation Reliability Evidence

Confirm tests prove:

## Answer PUT

```text
uncertain -> same mutation snapshot
GET equal -> confirmed
GET different/in_progress -> dirty retry state
GET terminal -> server state wins
```

## File PUT

```text
uncertain -> same selected file
GET metadata alone != exact-byte confirmation
retry -> valid 200 confirmation
```

No false success.

---

# 72. Mandatory Submit Safety Evidence

Confirm tests prove:

```text
dirty draft -> no POST
pending file -> no POST
active answer save -> no POST
uncertain answer -> no POST
active file upload -> no POST
uncertain file -> no POST
Attempt refreshing -> no POST
0 answers clean -> POST allowed
```

Also prove FE-005 claims route operation gate before answer/file mutation can start.

---

# 73. Full Diff / Scope Review

Inspect complete Stage 7 frontend diff for:

```text
TODO
FIXME
debugPrint
print(
temporary
workaround
```

where relevant.

Confirm:

- no hidden scoring/checking UI;
- no Stage 8 Blitz;
- no Stage 9 Teacher review;
- no Parent result UI;
- no speculative offline engine;
- no large generic framework;
- no duplicate file stack;
- no test weakening.

---

# 74. Integration Readiness Review

The frontend checkpoint does not run real-stack Stage 7 E2E.

Before PASS, verify the production frontend exposes stable testable surfaces needed by S07-INT-001:

- canonical routes;
- stable meaningful widget keys/semantics where integration tests require them;
- deterministic status/action labels;
- injectable file picker/idempotency generator where test harness requires deterministic inputs;
- no test-only production branch;
- no arbitrary client sleeps required for correctness.

Do not modify integration harness during the Phase 2 review.

---

# 75. Integration Harness Preflight Handoff

If Frontend Phase 2 passes, the next gate is:

```text
S07-INT-001 — Real-Stack Student Homework E2E
```

But before the **first full real-stack Stage 7 runner invocation**, ChatGPT must perform the workflow-required focused **Integration Harness Preflight**.

That later preflight reviews:

- integration runner;
- Stage 7 seeder/fixture setup;
- stable widget selectors;
- route targets;
- file fixture sources;
- idempotency assumptions;
- condition-based waits;
- tenant-safe deterministic actors/data;
- backend DB oracle/persistence checks;
- teardown/reset;
- environment assumptions.

Do not silently start broad E2E immediately after frontend PASS without that preflight.

---

# 76. Findings Record

Record highest severity first.

| ID | Severity | Finding | Evidence | Required correction |
|---|---|---|---|---|
| `<S07-FE-R01>` | `<P1/P2/P3>` | `<issue>` | `<file/test/location>` | `<focused fix boundary>` |

If none:

```text
No findings.

P1 = 0
P2 = 0
P3 = 0
```

---

# 77. Verdict

Choose exactly:

```text
PASS
NOT ACCEPTED
```

`PASS` requires:

- all entry conditions satisfied;
- FE-001…005 on audited `main`;
- full frontend suite PASS;
- `flutter analyze --no-pub` PASS;
- full format check PASS;
- Windows debug build PASS;
- Android debug build PASS;
- `git diff --check` PASS;
- `P1 = 0`;
- `P2 = 0`;
- no unresolved privacy/session/routing/idempotency/mutation/file/Submit conflict;
- required Stage 7 frontend acceptance criteria verified;
- previous Stage shared regressions remain green.

Default target:

```text
P3 = 0
```

---

# 78. Evidence Validity After a Focused Fix

If initial review finds a defect and a later focused fix is delivered, ChatGPT decides which prior evidence remains valid.

Default examples:

## Docs/test-only adjustment

May preserve production build/full-suite evidence if no runtime behavior changed.

## Narrow Widget-only fix

Rerun:

- focused affected widget tests;
- analyze/format;
- materially affected route/accessibility checks.

Full suite/build may remain valid if ChatGPT determines runtime surface risk is narrow.

## Shared Student session/router/state fix

Normally invalidates broader:

- full frontend test suite;
- router/session regression surface;
- relevant build/checkpoint evidence.

## DTO/API/repository change

Normally invalidates:

- full frontend suite;
- affected strict DTO/data tests;
- integration contract surface.

## Shared `LocalFileActions`/protected transfer change

Invalidates:

- Stage 5 shared-file regressions;
- file transfer tests;
- relevant build/static evidence.

## Submit gate/idempotency fix

Invalidates:

- FE-003/004 mutation coordination regressions;
- Submit tests;
- full suite where cross-task state coordination changed materially.

Any previously failing mandatory command must eventually pass.

Do not rerun everything by habit, and do not preserve evidence that a later change materially invalidates.

---

# 79. PASS Follow-Up

If:

```text
Verdict: PASS
```

record final evidence:

```text
Audited origin/main: <sha>
Frontend implementation base: <sha>

Full frontend suite: <result>
Analyze: <result>
Format check: <result>
Windows debug build: <result>
Android debug build: <result>
git diff --check: PASS

P1 = 0
P2 = 0
P3 = 0
```

Then:

```text
Stage 7 Frontend block = accepted integrated checkpoint
```

Next permitted gate:

```text
S07-INT-001
```

with:

```text
Integration Harness Preflight first
```

Do not perform Stage Closure yet.

---

# 80. NOT ACCEPTED Follow-Up

If:

```text
Verdict: NOT ACCEPTED
```

do not proceed to Stage integration.

ChatGPT must:

1. record findings;
2. group only truly coupled findings;
3. issue focused fix contract(s);
4. avoid reopening unrelated accepted tasks;
5. define proportional focused fix verification;
6. leave routine delivery to Project Owner;
7. decide checkpoint evidence invalidation after each fix;
8. rerun every previously failing mandatory check;
9. rerun only materially invalidated previously passing checks;
10. issue a new final Frontend Phase 2 verdict.

Do not fix findings inside this review.

---

# 81. Final Review Record Template

When executed, replace `Pending` values with evidence and conclude with:

```text
S07-FE-PHASE-2

Audited origin/main:
<sha>

Frontend implementation base:
<sha>

Frontend tasks:
S07-FE-001: <PR/SHA>
S07-FE-002: <PR/SHA>
S07-FE-003: <PR/SHA>
S07-FE-004: <PR/SHA>
S07-FE-005: <PR/SHA>

Verification:
Full frontend suite: <PASS/FAIL + counts>
Analyze: <PASS/FAIL>
Format check: <PASS/FAIL>
Windows debug build: <PASS/FAIL>
Android debug build: <PASS/FAIL>
git diff --check: <PASS/FAIL>

Read-only integrated review:
Architecture: <PASS/FAIL>
Strict DTO/API: <PASS/FAIL>
Question privacy: <PASS/FAIL>
Session/stale completion: <PASS/FAIL>
Routing: <PASS/FAIL>
Start idempotency: <PASS/FAIL>
Attempt hierarchy: <PASS/FAIL>
Eight non-file editors: <PASS/FAIL>
Answer uncertainty: <PASS/FAIL>
File upload/replacement: <PASS/FAIL>
File uncertainty: <PASS/FAIL>
Protected submission transfer: <PASS/FAIL>
Unsaved navigation: <PASS/FAIL>
Submit readiness: <PASS/FAIL>
Submit idempotency: <PASS/FAIL>
Submit operation gate: <PASS/FAIL>
Deadline/close reconciliation: <PASS/FAIL>
Desktop/mobile: <PASS/FAIL>
Accessibility/responsiveness: <PASS/FAIL>
Previous-stage regressions: <PASS/FAIL>
Integration readiness: <PASS/FAIL>

Findings:
P1 = <n>
P2 = <n>
P3 = <n>

Verdict:
<PASS / NOT ACCEPTED>

Next permitted gate:
<S07-INT-001 with Integration Harness Preflight first, only if PASS>
```

This checkpoint performs no implementation.
