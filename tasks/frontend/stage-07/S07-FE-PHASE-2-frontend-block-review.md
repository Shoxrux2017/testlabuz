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
| Current contract review baseline | `origin/main @ ad40fc2bbca1efd348b8da25651bc3d6e5e9d8f7` |
| Contract readiness | `PASS — corrected/revalidated`; checkpoint execution remains `Pending` |
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
- uncertain answer mutation reconciliation without blind PUT replay;
- file picker/upload/replace;
- uncertain file upload reconciliation without blind PUT replay;
- protected Student submission Open/Save As;
- unsaved-work navigation guards;
- final Submit readiness/confirmation;
- same-key uncertain Submit retry;
- symmetric route-level Submit operation gate;
- owned Check-current Submit reconciliation;
- `completed` vs `reconciledTerminal` Submit semantics;
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
- uncertain idempotent Start/Submit retry creates a new idempotency key;
- ordinary answer/file PUT blindly replays an uncertain mutation and can overwrite a newer intervening server state;
- Submit allowed while unsaved/uncertain/local-state-mismatched work exists;
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

Audit all Stage 7 frontend DTOs and their request-context validation.

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

Baseline requirements:

- exact keys and exact nullability;
- canonical UUIDs;
- strict enums;
- finite numeric parsing;
- malformed success => `ApiFailureKind.invalidResponse`;
- no raw transport map becomes application/presentation authority.

## Stage 7 timestamp contract

Every Homework/Attempt/answer mutation timestamp owned by the Stage 7 Student
Homework transport must use exact whole-second UTC:

```text
YYYY-MM-DDTHH:MM:SSZ
```

Reject fractional seconds, omitted seconds, non-`Z` offsets and invalid dates.

Do not silently reuse an older permissive Student Topic timestamp parser where
the Stage 7 contract is stricter.

## Homework list/detail invariants

Verify list DTO/parser enforces at minimum:

```text
response page/per_page match requested query
every row.topicId == requested topicId
Homework IDs unique
pagination totals/last_page internally coherent
```

Verify the one-shot out-of-range correction remains:

```text
target = total == 0 ? 1 : max(1, min(lastPage, requestedPage - 1))
```

with no correction loop and no false empty publication before correction.

## Safe Question collection invariants

Verify:

```text
Question IDs unique
positions unique
positions exactly 1..N
response order ascending by position
```

For typed children:

- choice option IDs are unique and safe;
- Multiple Choice has valid positive `maxSelections`;
- Ordering item IDs are unique/non-empty;
- Matching/fill child IDs are unique within their safe collections.

## Attempt lifecycle invariants

For every Attempt require coherent `startedAt`, `submittedAt`, `finalizedAt`,
`deadlineAt` and finalization reason.

At minimum:

```text
startedAt <= submittedAt when submittedAt != null
startedAt <= finalizedAt when finalizedAt != null
```

`in_progress` requires:

```text
submittedAt = null
finalizedAt = null
finalizationReason = null
```

`student_submit` requires:

```text
submittedAt != null
submittedAt == finalizedAt
if deadlineAt != null => finalizedAt < deadlineAt
```

`homework_deadline_auto_submit` requires:

```text
deadlineAt != null
submittedAt = null
finalizedAt == deadlineAt
```

`task_closed_auto_finalize` requires:

```text
submittedAt = null
if deadlineAt != null => finalizedAt < deadlineAt
```

At/effectively after deadline, deadline semantics must win.

## Saved-answer cross-collection invariants

Verify:

- answer `questionId` unique;
- answer type equals referenced safe Question type;
- choice IDs belong to Question options;
- Multiple Choice count does not exceed `maxSelections`;
- matching left/right IDs belong to the corresponding safe side sets;
- ordering item IDs belong to Question items;
- ordering submitted positions are unique and within `1..Question.items.length`;
- fill blank IDs belong to Question blanks;
- persisted written/fill text is semantically non-empty while exact non-empty
  text is preserved.

## File metadata invariants

Verify safe saved-file metadata:

- canonical file UUID;
- supported canonical extension;
- non-empty original filename;
- original filename max `500` Unicode code points/runes;
- original filename extension matches canonical extension case-insensitively;
- `sizeBytes > 0` and within the Stage 7 platform hard bound;
- no storage disk/key/checksum/owner/tenant internals enter Student domain.

## Mutation-response request-context validation

Answer/file mutation response parsing must validate against the **current safe
`StudentQuestion`**, not only a route Question ID/type string.

Verify current-safe-Question bounds for Multiple/Matching/Ordering/Fill and file
policy metadata.

## Submit-response semantic validation

A valid Submit/replay `200` must prove:

```text
Attempt hierarchy matches route target
status in submitted / waiting_for_teacher_review / checked
finalizationReason = studentSubmit
submittedAt != null
finalizedAt == submittedAt
```

A `200` carrying deadline/close finalization is malformed success and therefore
uncertain, not confirmed Submit success.

No score/checking/answer-key field may be accepted by Stage 7 Student DTOs.

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
- pagination is server-authoritative and one-shot correction follows the
  contract from Section 15;
- list DTO validates requested query/page/per-page/topic and duplicate IDs;
- no client search/sort behavior outside contract;
- detail route is canonical;
- direct historical Homework detail can load from:
  ```text
  GET /student/homework/{homeworkId}
  ```
  without requiring successful `GET /student/topics/{topicId}` or current Group
  membership;
- direct Homework success validates returned Topic/Homework hierarchy against
  the route target;
- authoritative Homework `404` invalidates the corresponding Topic Homework
  list;
- Homework status/my-status/attempt counts come from backend;
- Start is offered only from confirmed-current/non-stale Homework detail data;
- no Start action is authorized by retained loading/refreshing/stale/error/
  notFound state;
- no score displayed;
- `score_visible=false` enforced;
- deadline formatting uses Institution timezone;
- device time does not recalculate eligibility or remaining attempts.

Historical persisted assignment state, not current Group membership, remains the
Student read/execution basis.

---

# 18. Student Router Review

Expected Stage 7 Student routes:

```text
/student

/student/topics/:topicId

/student/topics/:topicId/homework/:homeworkId

/student/topics/:topicId/homework/:homeworkId/attempts/:attemptId
```

Verify the route classifiers remain mutually exclusive:

```text
isStudentTopicDetailPath
  = exact Topic route only

isStudentHomeworkDetailPath
  = exact Homework route only

isStudentHomeworkAttemptPath
  = exact Attempt route only
```

Extractor semantics:

```text
studentTopicIdFromPath
  = Topic ID from exact Topic/Homework/Attempt

studentHomeworkIdFromPath
  = Homework ID from exact Homework/Attempt only

studentAttemptIdFromPath
  = Attempt ID from exact Attempt route only
```

Verify:

- no competing flat frontend Attempt route;
- all UUID path parsers are exact;
- extra/malformed segments are rejected;
- query/fragment behavior follows the existing exact Student route semantics;
- `isStudentApprovedLocation` accepts only Student root or the three exact route
  shapes above;
- direct entry is guarded;
- valid Homework and Attempt deep-links are preserved through auth bootstrap on
  desktop and mobile;
- Attempt deep-link hierarchy is validated through Student Homework detail +
  Attempt GET, not current Topic membership;
- wrong/ineligible session cannot transiently render protected Student content;
- Teacher/Institution Admin/Parent routing remains unchanged.

A broader ID extractor must never be used to make a parent route classifier
match its nested descendants.

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
parent Attempt publication/generation
operation generation
read generation
active mutation/reconciliation identity
idempotency logical operation identity
Submit resolution/check generation
```

Verify stale completion cannot:

- overwrite another Student's Homework;
- overwrite another Attempt;
- publish after logout;
- publish across Institution switch;
- navigate after target change;
- show stale SnackBar;
- apply a stale answer save;
- resolve an answer uncertainty from an unrelated normal parent refresh;
- apply a stale file upload;
- resolve a file uncertainty from metadata-only unrelated refresh;
- open/save an old file after replacement;
- restore editor/file mutation state after authoritative terminal publication;
- adopt a Submit result into a newer route/session;
- let an older Check-current GET overwrite a newer same-key Submit Retry result.

Terminal Attempt publication must invalidate obsolete answer/file mutation and
reconciliation generations.

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

From confirmed-current FE-001 Homework detail:

```text
inProgressAttempt != null
-> Resume
-> direct nested Attempt navigation
-> no Start POST
```

The execution-route GET remains authoritative.

## New Start

A new Start mutation may be exposed only when the FE-001 Homework detail is
confirmed-current/non-stale `data`:

```text
status = active
remaining > 0
inProgressAttempt = null
no active Start operation
```

No Start from loading/refreshing/stale/error/notFound retained data.

Request:

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

Both valid success cases navigate to the returned Attempt after hierarchy
validation.

No optimistic:

```text
used++
remaining--
myStatus patch
```

Session/account failures:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

must clear Start key/ownership and use existing Student auth/session
reconciliation rather than ordinary feature failure UX.

No device-time deadline authority.

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
-> Student Homework detail confirms topicId/homeworkId

route attemptId
-> Attempt confirms assessmentId == homeworkId
```

The direct Attempt route must not depend on successful current Topic detail/current
Group membership.

Execution content/editability may render only after both required parent pieces
are confirmed-current for the route:

```text
Homework detail = current data
Attempt = current data
```

Retained refreshing/stale parent data is not sufficient to authorize a new
mutation.

Frontend route hierarchy mismatch must not render a valid resource under a
wrong parent path.

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

- Question IDs/positions satisfy Section 15 exact collection invariants;
- answer `question_id` is unique;
- answer type matches the referenced Question type;
- choice option IDs belong to Question;
- Multiple Choice count <= referenced `maxSelections`;
- matching IDs belong to left/right safe sets and remain unique;
- ordering IDs belong to safe items;
- ordering submitted positions are unique, `>=1` and
  `<= Question.items.length`; partial/non-contiguous values remain valid;
- fill IDs belong to safe blanks and remain unique;
- written/fill persisted text is semantically non-empty, but exact non-empty
  text is preserved without trim/normalization;
- file answer exposes only canonical safe metadata.

Attempt/answer timestamps use the exact Stage 7 whole-second UTC `...Z` format
from Section 15.

No checking/score/storage/internal fields.

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

- Save is authorized only from confirmed-current/non-stale in-progress Attempt
  data;
- loading/refreshing/stale/error/notFound parent state cannot send a PUT;
- Save disabled when semantic no-op;
- dirty state compares semantic canonical answer vs confirmed server answer;
- no debounce/timer autosave;
- no route-pop autosave;
- mutation response is validated against the current safe `StudentQuestion`;
- malformed/mismatched `200` becomes uncertain;
- valid server mutation response becomes confirmed base;
- parent Attempt refresh is reconciliation only;
- terminal parent publication invalidates obsolete save/reconciliation
  generations and makes the shell read-only.

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

Ordinary answer PUT has:

```text
no Idempotency-Key
no version/ETag compare-and-swap precondition
```

Verify uncertain result:

```text
connection
timeout
cancelled
invalidResponse
unknown
5xx/unknown server
```

retains the exact canonical `pendingMutationSnapshot` but **does not blindly
repeat the PUT**.

Required recovery:

```text
uncertain
-> owned authoritative GET Attempt reconciliation
```

Only the explicitly owned reconciliation GET may resolve that uncertainty.

Outcomes:

```text
GET server answer semantically equals pending snapshot
  => confirmed saved

GET differs + Attempt still confirmed-current in_progress
  => refreshed server answer becomes base
  => pending snapshot becomes local dirty intent
  => later Student Save is a new explicit mutation

GET terminal
  => authoritative server state wins
  => no further mutation

GET reconciliation itself fails non-authoritatively
  => uncertainty/snapshot remain
```

An ordinary parent refresh must not silently resolve the uncertain Question.

No blind `Retry save` action/path is allowed.

A newer intervening server answer must never be overwritten automatically by the
old uncertain snapshot.

---

# 33. One Active Non-File Save / Reconciliation Review

Verify FE-003 permits at most one authoritative answer-state operation per
Attempt at a time:

```text
one active PUT Save
OR
one active uncertain-outcome GET reconciliation
```

Other local drafts may remain editable when allowed, but no second Save starts.

Save entry must synchronously:

```text
check route Submit gate == idle
-> claim FE-003 saving ownership
-> only then first await / PUT
```

Uncertainty reconciliation is likewise generation/session/target/question-bound.

An ordinary in-progress parent refresh must not resolve an uncertain Question.

A confirmed terminal parent refresh must:

- invalidate active save/reconciliation generation;
- clear unsavable dirty/uncertain state;
- ignore late obsolete PUT/GET completions;
- show server read-only state.

This keeps the server Attempt-row serialization and client state coherent.

---

# 34. File Picker / Local Validation Review

Verify FE-004:

- existing `file_picker` reused;
- no new package;
- safe extensions come from the current safe Question;
- picker can begin only from confirmed-current/non-stale in-progress Attempt
  state and idle Submit gate;
- loading/refreshing/stale/error/notFound parent state cannot start picker/upload;
- picker cancel is neutral;
- extension revalidated after pick;
- `length > 0`;
- `length <= current Question.answerUi.maxSizeBytes`;
- filename is non-empty, not `.`/`..`, has a final extension and satisfies:
  ```text
  name.runes.length <= 500
  ```
  matching the backend 500-Unicode-code-point boundary;
- UTF-8 byte length is not substituted as the filename acceptance limit;
- no local binary signature parser;
- no local MIME authority.

Backend remains authoritative for content inspection and the final effective
upload limit.

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
- upload progress is transport-only, not success proof;
- upload begins only from confirmed-current/non-stale in-progress Attempt state;
- mutation response is parsed against the current safe file Question;
- response extension/size/name match the selected upload;
- response extension is permitted by current safe Question policy;
- replacement preserves previous server `File.id`;
- response `updatedAt` uses exact whole-second UTC Stage 7 format;
- malformed/mismatched `200` is uncertain, not success.

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

File PUT has no idempotency key/version precondition.

Verify:

```text
timeout/connection/cancelled/unknown/invalid success/unknown 5xx
=> selected file retained as local intent
=> outcome uncertain
=> NO blind multipart PUT replay
```

Required recovery:

```text
uncertain
-> owned authoritative GET Attempt reconciliation
```

A GET showing matching:

```text
filename
size
extension
```

does **not** prove exact selected bytes committed because checksum is intentionally
not exposed.

After owned reconciliation:

```text
terminal Attempt
  => server state wins; selected local file/uncertainty cleared

in_progress Attempt
  => refreshed serverFile becomes current base
  => retained selected file is revalidated against refreshed safe Question policy
  => if valid, it becomes local `ready` unsaved intent
  => a later Upload is a NEW explicit Student mutation decision

non-authoritative GET failure
  => uncertainty remains
```

No blind `Retry upload` for uncertain outcome.

The only same-file Retry that remains valid is the separately confirmed
`file_upload_failed` case in Section 38.

Terminal parent publication invalidates upload/reconciliation generations and
late obsolete picker/PUT/GET completions.

---

# 38. Deterministic File Failure Review

Verify:

```text
unsupported_file_type
file_too_large
file_upload_failed
deadline_passed
attempt_not_editable
task_not_active
task_closed
task_archived
business_conflict
```

are handled with the contracted confirmed/uncertain distinctions.

Specifically:

```text
file_upload_failed
```

is an explicit confirmed storage-write failure. The selected local file may be
retained and `Retry upload` may be offered only as a **new explicit action**
after rechecking:

```text
confirmed-current in_progress Attempt
current safe file Question
route Submit gate idle
selected-file local validation
```

This confirmed-failure Retry is not the blind uncertain replay forbidden by
Section 37.

Unsupported/too-large and lifecycle outcomes follow the corrected FE-004
selection-clearing/reconciliation rules.

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

A new Open/Save As transfer may begin only when the current FE-002 Attempt
controller has confirmed-current `data` proving the requested:

```text
route target
questionId
fileId
```

still identifies the current saved file answer. The Attempt may be in-progress
or terminal because transfer is read-only.

Do not start a transfer from loading/refreshing/stale/error/notFound parent
state.

Shared protected parser must still enforce:

- status 200;
- canonical supported Content-Type;
- attachment Content-Disposition;
- `Cache-Control: private, no-store`;
- `X-Content-Type-Options: nosniff`;
- non-empty bytes;
- bounded bytes.

After download and before local Open/Save, re-check the same current saved-file
target and operation generation.

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
- `LocalFilePlatformAdapter` signature compatibility is updated for every
  affected implementation/fake, including:
  ```text
  test/core/network/protected_learning_material_transfer_test.dart
  test/features/student/student_topic_detail_transfer_controller_test.dart
  test/features/teacher/teacher_material_transfer_controller_test.dart
  integration_test/stage5_e2e_support.dart
  ```
- Stage 5 file-transfer tests remain green;
- `flutter analyze --no-pub` covers the integration helper compile compatibility;
- no Stage 5 E2E rerun is required solely by that helper signature touch unless a
  later material behavior change invalidates it;
- no broad shared file refactor entered the task.

---

# 42. Unsaved Work Navigation Guard Review

Verify route-leave priorities compose across FE-003/004/005.

Expected priority:

```text
1. submitting
2. Submit checking / submitUncertain
3. answer/file mutation uncertainty/reconciliation
4. dirty non-file / selected local file
5. clean leave
```

For active `submitting`, route leave is blocked with Stay-only behavior.

For Submit uncertain/checking state, explicit Leave may discard the current
Submit replay/reconciliation context only after warning.

For answer/file uncertainty, leave warning must describe loss of local
uncertainty/reconciliation state; it must not imply a blind PUT retry contract.

No stacked multiple dialogs for one Back action.

No automatic save/upload/submit on leave.

Clean/terminal route leaves normally.

---

# 43. Submit Readiness Review

Submit may run only when all current state belongs to the same:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
confirmed Attempt publication/generation
Question set
```

Required:

```text
Attempt controller = exact confirmed-current/non-stale data
Attempt.status = in_progress
FE-003 editor state initialized/current for same publication
FE-004 file state initialized/current for same publication
no dirty non-file drafts
no non-file save/reconciliation active
no non-file uncertain save
no pending selected file
no file picker/upload/reconciliation active
no file uncertain upload
route operation gate = idle
```

Block Submit for:

```text
loading
refreshing
stale/retained-only
error
notFound
session/account reconciliation
uninitialized FE-003/004 state
older editor/file Attempt publication
Question-set/state ownership mismatch
```

The typed blocker:

```text
localStateUnavailable
```

must cover local ownership/publication states that cannot be proven current.

Verify Submit is **not** blocked merely because Questions are unanswered.

Zero-answer Attempt:

```text
must remain submittable
```

when all current local state is clean and aligned.

No device-time lifecycle authority.

---

# 44. Confirmed Answer Count Review

Confirmation shows:

```text
questionCount
confirmedAnsweredCount
unansweredCount
```

Count may merge latest confirmed:

- current FE-002 Attempt GET answers;
- FE-003 confirmed non-file mutation result not yet incorporated into parent GET;
- FE-004 confirmed file mutation result not yet incorporated into parent GET.

Every overlay must prove it belongs to the same current:

```text
StudentSessionKey
Attempt route target
Question ID
```

and is newer than/not yet incorporated into the current Attempt publication.

After a newer authoritative Attempt GET has synchronized/rebased FE-003/004
state, stale mutation overlays must not be re-applied over it.

Do not count:

- dirty drafts;
- selected but unuploaded file;
- uncertain answer mutation snapshot;
- uncertain file selection/snapshot;
- stale/unowned editor/file overlay.

If overlay ownership/publication freshness cannot be proven:

```text
localStateUnavailable
```

rather than inventing an answer count.

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

# 46. Submit Transport / Success Contract Review

Exact:

```text
POST /student/attempts/{attempt}/submit
Idempotency-Key: UUID
body = {}
no query
```

Success transport:

```text
200
```

Strict top-level response:

```text
data
message
```

with exact success message and the delivered strict Attempt parser reused.

A valid Submit/replay `200` additionally requires:

```text
returned Attempt.id == route attemptId
returned Attempt.assessmentId == route homeworkId
status in submitted / waiting_for_teacher_review / checked
finalizationReason = studentSubmit
submittedAt != null
finalizedAt == submittedAt
```

Later `waiting_for_teacher_review` / `checked` is allowed only as progression of
the same original `student_submit`.

A `200` carrying deadline/close finalization or other semantic contradiction is:

```text
invalidResponse
=> uncertain
=> SAME Submit Idempotency-Key retained
```

No duplicate Submit DTO lifecycle parser.

No score/checking fields.

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
gate = submitting
```

after final synchronous readiness re-check and before its first async
wait/request.

FE-003 and FE-004 mutation entry points must symmetrically operate as:

```text
check route gate == idle
-> synchronously claim own saving/selecting/uploading operation state
-> only then first await / PUT / picker
```

Correct race outcomes:

```text
answer/file operation claims first
=> Submit sees active blocker
=> no Submit POST / no gate claim

Submit claims gate first
=> FE-003 Save and FE-004 picker/upload/confirmed-file_upload_failed Retry refuse
=> no PUT/picker
```

The corrected FE-003/004 uncertain PUT flows do not have blind mutation Retry
entry points.

Verify both ordering directions with controlled completers/no arbitrary sleeps.

This must exist in application logic, not only disabled Widgets.

No broad global mutation manager/provider cycle.

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
editors/file mutations frozen
```

Actions:

```text
Retry submission
Check current Attempt
```

Same-key `Retry submission` is safe because Submit has durable backend
idempotency.

However, exactly **one Submit resolution operation** may run at a time:

```text
Retry active => Check disabled
Check active => Retry disabled
duplicate Retry/Check suppressed
```

`Check current Attempt` may expose a typed `checking` state while the route gate
remains `submitUncertain`.

No normal Submit/new key.

A stale older Check/Retry completion must not overwrite a newer resolution.

---

# 50. Owned Check Current Attempt Review

During uncertain Submit, `Check current Attempt` must be an explicitly owned
reconciliation operation bound to at least:

```text
StudentSessionKey
Attempt route target
pending Submit Idempotency-Key
logical Submit generation
check generation
```

Only that owned GET completion may resolve Submit state.

A late Check completion must be ignored after:

- valid same-key Retry `200`;
- deterministic Submit resolution;
- explicit uncertain-route Leave;
- session change;
- route target change;
- disposal/newer Check generation.

## GET terminal `student_submit`

The GET proves that the Attempt is explicitly submitted, but **does not prove**
that this current pending client logical operation/key caused the terminal state;
another device/request may have won first.

Required:

```text
clear key/gate
state = reconciledTerminal
typed reason = studentSubmitAlreadyTerminal
neutral notice such as "This Attempt is already submitted."
```

Do not show current-operation:

```text
Attempt submitted successfully.
```

The finalization summary may still show `Submitted by you` because that label
describes authoritative server reason, not provenance of this client call.

## GET terminal deadline/close

Required:

```text
state = reconciledTerminal
clear key/gate
adopt authoritative terminal Attempt
show deadline/close finalization reason
no explicit Submit success
```

## GET still `in_progress`

Required:

```text
state returns to uncertain
same key retained
gate remains submitUncertain
```

Do not conclude failure.

Same-key Retry remains available after Check completes.

## Check GET fails non-authoritatively

Remain uncertain with the same key/gate.

An ordinary unrelated Attempt refresh must not resolve the Submit logical state.

---

# 51. Submit Success Adoption Review

On a valid Submit/replay `200` satisfying Section 46:

- returned Attempt hierarchy checked;
- terminal status is allowed;
- `finalizationReason = studentSubmit`;
- explicit submit timestamps are coherent;
- current Attempt controller adopts authoritative returned Attempt immediately
  through a focused route/session-safe adoption path;
- Submit state = `completed`;
- editors become terminal/read-only immediately;
- pending local editor/file state reconciles;
- Homework detail/list invalidated or marked stale;
- no optimistic local attempt-count patch;
- obsolete Check/retry generations are invalidated.

A terminal Attempt discovered only by Check-current uses the separate
`reconciledTerminal` path from Section 50 and must not be promoted to
current-operation `completed`.

No generic arbitrary model injection API.

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

Review three distinct mutation categories and verify their recovery strategies
are **not** conflated.

## Start

High-risk idempotent POST.

```text
uncertain
=> retain SAME Idempotency-Key
=> explicit Retry may resend same Start request
```

## Ordinary non-file answer PUT

No idempotency/version precondition.

```text
uncertain
=> retain pending mutation snapshot
=> NO blind PUT retry
=> owned authoritative GET reconciliation
=> if server differs/in_progress, snapshot becomes local dirty intent
=> later Save is a new explicit mutation
```

## File PUT

No idempotency/version precondition and checksum is not exposed to Student.

```text
uncertain
=> retain selected file as local intent
=> NO blind PUT retry
=> owned authoritative GET reconciliation
=> metadata equality is not exact-byte proof
=> later Upload is a new explicit mutation
```

Exception:

```text
file_upload_failed
```

is a confirmed storage-write failure and may expose a new explicit same-file
Retry after current preconditions are revalidated.

## Submit

High-risk durable-idempotent POST.

```text
uncertain
=> retain SAME Idempotency-Key
=> explicit Retry may resend same Submit request
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
- answer/file uncertainty reconciliation does not falsely mark unrelated parent
  refresh as success;
- newer authoritative Attempt GET rebases/supersedes stale FE-003/004 confirmed
  overlays;
- Submit success invalidates Homework detail/list;
- Submit Check-current terminal reconciliation adopts current Attempt without
  optimistic Homework counts;
- no optimistic list pagination/count mutation.

Avoid broad unrelated Student feature invalidation and invalidation loops.

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
LocalFilePlatformAdapter fakes/helpers
```

remain compile-safe/green.

Learning Material Save As still uses:

```text
Save learning material
```

Student submission Save As uses:

```text
Save submitted answer
```

Confirm `integration_test/stage5_e2e_support.dart` was updated only as needed for
the adapter signature and remains analyzer-clean.

No MIME/header regression.

No broad protected-file transport rewrite.

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
| Student Homework Topic section + failure isolation | FE-001 | `<tests/code>` | Pending |
| Strict Homework list/query/pagination invariants | FE-001 | `<tests/code>` | Pending |
| Historical direct Homework detail independent of current Topic membership | FE-001 | `<tests/code>` | Pending |
| Safe Student Question DTOs + exact positions/timestamps | FE-001 | `<tests/code>` | Pending |
| Mutually exclusive canonical Topic/Homework route classifiers | FE-001 | `<tests/router>` | Pending |
| Start create/resume UX from confirmed-current detail only | FE-002 | `<tests>` | Pending |
| Secure UUID v4 generator | FE-002 | `<tests>` | Pending |
| Same-key uncertain Start retry | FE-002 | `<tests>` | Pending |
| Canonical Attempt route + bootstrap deep-link preservation | FE-002 | `<tests/router>` | Pending |
| Strict Attempt lifecycle/saved-answer read | FE-002 | `<tests>` | Pending |
| Eight non-file editors | FE-003 | `<tests>` | Pending |
| Semantic no-op/clear | FE-003 | `<tests>` | Pending |
| Uncertain answer GET reconciliation / no blind PUT retry | FE-003 | `<tests>` | Pending |
| Terminal generation invalidation for answer editor | FE-003 | `<tests>` | Pending |
| Unsaved draft leave guard | FE-003 | `<tests>` | Pending |
| File picker + 500-rune filename/current-policy validation | FE-004 | `<tests>` | Pending |
| Multipart upload/replacement + stable File ID | FE-004 | `<tests>` | Pending |
| Uncertain file GET reconciliation / no blind PUT retry | FE-004 | `<tests>` | Pending |
| `file_upload_failed` confirmed-failure retry distinction | FE-004 | `<tests>` | Pending |
| Own protected submission Open/Save As from current target | FE-004 | `<tests>` | Pending |
| LocalFileActions/Stage 5 compatibility | FE-004 | `<tests/analyze>` | Pending |
| Submit readiness + local-state publication ownership | FE-005 | `<tests>` | Pending |
| Zero-answer Submit allowed | FE-005 | `<tests>` | Pending |
| Strict `student_submit` proof for valid Submit `200` | FE-005 | `<tests>` | Pending |
| Same-key uncertain Submit retry | FE-005 | `<tests>` | Pending |
| Symmetric Submit route-operation gate | FE-005 | `<tests>` | Pending |
| Owned Check-current resolution / no Retry race | FE-005 | `<tests>` | Pending |
| `completed` vs `reconciledTerminal` semantics | FE-005 | `<tests>` | Pending |
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
historical assigned Homework/Attempt does not depend on current Group membership
resource-not-found reconciliation
session switch stale completion
terminal publication invalidates obsolete answer/file operations
another file ID cannot be acted on as current
protected download requires current saved file target
wrong role Student route gating
inactive user/Institution session reconciliation
password-change-required reconciliation
```

Frontend is not backend authorization, but it must not accidentally reuse stale/
foreign identifiers after server denial or make current Group membership a
frontend authorization substitute for the persisted assignment snapshot.

---

# 70. Mandatory Idempotency Evidence

Confirm tests prove:

## Start

```text
timeout -> same key retry
5xx -> same key retry
invalid success -> same key retained
201 create
200 resume
session/account gate failure -> key/ownership cleared
```

## Submit

```text
timeout -> same key retry
5xx -> same key retry
invalid success -> same key retained
valid 200 requires terminal student_submit proof
HTTP 200 carrying deadline/close reason -> invalidResponse/uncertain + same key
Check current student_submit terminal -> reconciledTerminal/already submitted
Check current deadline/close terminal -> reconciledTerminal/no explicit success
Check current in_progress -> remains uncertain with same key
```

No new key is generated automatically in either idempotent uncertain flow.

Only Start and Submit use same-key mutation replay; ordinary answer/file PUT do
not.

---

# 71. Mandatory Local Mutation Reliability Evidence

Confirm tests prove:

## Answer PUT

```text
uncertain -> exact mutation snapshot retained
uncertain -> NO blind PUT retry
owned GET equal -> confirmed saved
owned GET different/in_progress -> refreshed server base + old intent dirty
owned GET terminal -> server state wins
ordinary parent refresh -> does not silently resolve uncertainty
terminal parent -> active generations invalidated
malformed 200/current-Question mismatch -> uncertain
```

## File PUT

```text
uncertain -> same selected file retained as local intent
uncertain -> NO blind PUT retry
owned GET metadata equality != exact-byte confirmation
owned GET in_progress -> refreshed serverFile base + selected file revalidated
owned GET terminal -> server state wins
file_upload_failed -> confirmed failure; explicit same-file Retry allowed only
                      after current preconditions are revalidated
terminal parent -> picker/upload/reconciliation generations invalidated
```

No false success and no automatic overwrite of an intervening newer server
answer/file.

---

# 72. Mandatory Submit Safety Evidence

Confirm tests prove:

```text
dirty draft -> no POST
pending file -> no POST
active/reconciling answer state -> no POST
uncertain answer -> no POST
active/reconciling file state -> no POST
uncertain file -> no POST
Attempt loading/refreshing/stale/error/notFound -> no POST
FE-003/004 local state uninitialized/older/mismatched -> no POST
0 answers clean/current/aligned -> POST allowed
```

Also prove symmetric operation entry:

```text
Submit claims route gate first
=> FE-003 Save / FE-004 picker-upload sends nothing

FE-003 Save claims saving first
=> Submit does not claim gate / no POST

FE-004 picker/upload claims operation first
=> Submit does not claim gate / no POST
```

For uncertain Submit:

```text
Retry active => Check disabled
Check active => Retry disabled
stale Check cannot overwrite newer valid Retry success
Leave/session/target invalidates Check/Retry generation
```

Use controlled completers; no arbitrary sleeps as synchronization evidence.

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

Also search/review for stale contract patterns such as:

```text
blind Retry save after uncertain answer PUT
blind Retry upload after uncertain file PUT
UTF-8 byte-count filename <= 500
Submit success accepting deadline/close reason under HTTP 200
Check-current student_submit treated as current-operation success
```

Confirm:

- no hidden scoring/checking UI;
- no Stage 8 Blitz;
- no Stage 9 Teacher review;
- no Parent result UI;
- no speculative offline engine;
- no large generic framework;
- no duplicate file stack;
- no test weakening;
- no unsafe uncertainty strategy inherited from an older task draft.

---

# 74. Integration Readiness Review

The frontend checkpoint does not run real-stack Stage 7 E2E.

Before PASS, verify the production frontend exposes stable testable surfaces
needed by S07-INT-001:

- canonical routes;
- bootstrap-preserved Homework/Attempt deep-links;
- stable meaningful widget keys/semantics where integration tests require them;
- deterministic status/action labels;
- explicit uncertainty recovery labels:
  - answer/file `Reload attempt`;
  - Submit `Retry submission` / `Check current Attempt`;
- deterministic `completed` vs terminal-reconciled presentation;
- injectable file picker/idempotency generator where test harness requires
  deterministic inputs;
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
- all corrected/revalidated FE-001…005 implementation contracts satisfied;
- full frontend suite PASS;
- `flutter analyze --no-pub` PASS;
- full format check PASS;
- Windows debug build PASS;
- Android debug build PASS;
- `git diff --check` PASS;
- `P1 = 0`;
- `P2 = 0`;
- no unresolved privacy/session/routing/idempotency/mutation/file/Submit conflict;
- no blind uncertain answer/file PUT replay;
- exact Stage 7 DTO/timestamp/lifecycle invariants verified;
- historical Homework/Attempt direct-route behavior verified;
- Submit `completed` vs `reconciledTerminal` semantics verified;
- required Stage 7 frontend acceptance criteria verified;
- previous Stage shared regressions remain green.

Default target:

```text
P3 = 0
```

---

# 78. Evidence Validity After a Focused Fix

If initial review finds a defect and a later focused fix is delivered, ChatGPT
decides which prior evidence remains valid.

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
- router/session/deep-link regression surface;
- relevant build/checkpoint evidence.

## DTO/API/repository change

Normally invalidates:

- full frontend suite;
- affected strict DTO/data tests;
- cross-collection/timestamp/lifecycle review;
- integration contract surface.

## Answer/file uncertainty-model fix

Normally invalidates:

- FE-003/004 controller tests;
- parent refresh/generation regressions;
- navigation-guard tests;
- Submit readiness coordination;
- full suite when shared state ownership changed materially.

## Shared `LocalFileActions`/protected transfer change

Invalidates:

- Stage 5 shared-file regressions;
- file transfer tests;
- adapter/helper compile compatibility;
- relevant build/static evidence.

## Submit gate/idempotency/reconciliation fix

Invalidates:

- FE-003/004 mutation coordination regressions;
- Submit tests;
- Check-current race tests;
- full suite where cross-task state coordination changed materially.

Any previously failing mandatory command must eventually pass.

Do not rerun everything by habit, and do not preserve evidence that a later
change materially invalidates.

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
Strict DTO/API/timestamps/lifecycle: <PASS/FAIL>
Question privacy: <PASS/FAIL>
Historical Homework/Attempt read authority: <PASS/FAIL>
Session/stale completion: <PASS/FAIL>
Routing/deep-link bootstrap: <PASS/FAIL>
Start idempotency/current-data gate: <PASS/FAIL>
Attempt hierarchy/saved-answer integrity: <PASS/FAIL>
Eight non-file editors: <PASS/FAIL>
Answer uncertainty/no-blind-retry: <PASS/FAIL>
File picker/500-rune validation: <PASS/FAIL>
File upload/replacement: <PASS/FAIL>
File uncertainty/no-blind-retry: <PASS/FAIL>
Protected submission transfer: <PASS/FAIL>
LocalFileActions previous-stage compatibility: <PASS/FAIL>
Unsaved navigation: <PASS/FAIL>
Submit readiness/local-state ownership: <PASS/FAIL>
Submit idempotency/strict student_submit 200: <PASS/FAIL>
Submit symmetric operation gate: <PASS/FAIL>
Submit Check-current ownership: <PASS/FAIL>
Submit completed-vs-reconciledTerminal: <PASS/FAIL>
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

