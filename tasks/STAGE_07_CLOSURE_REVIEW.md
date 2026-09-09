# Stage 7 Closure Review Contract — Student Homework and Submission Flow

## 1. Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-07-CLOSURE` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Status | `Pending — execute only after S07-INT-001 = PASS and all required delivery/fixes are complete` |
| Review mode | `Independent read-only closure audit followed by closure/documentation bookkeeping` |
| Verification model | `Workflow v3 — Lean Verification + Integration Harness Preflight discipline` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Stage index | `tasks/STAGE_07_TASK_INDEX.md` |
| Audited `origin/main` | `Resolve at closure execution time` |
| Local `main` | `Resolve at closure execution time` |
| Ahead/behind | `0/0 required` |
| Working tree | `Clean required` |
| Backend Phase 2 | `PASS required` |
| Frontend Phase 2 | `PASS required` |
| Integration | `S07-INT-001 PASS required` |
| Integration Harness Preflight | `PASS required` |
| Required Windows real-stack flow | `PASS required` |
| Required Android manual smoke | `PASS required` |
| Integration cleanup | `PASS required` |
| Open findings | `P1=0, P2=0 required; default P3=0 target` |
| Closure verdict | `Pending` |
| Next permitted gate after `STAGE CLOSED` | `Stage 8 planning/decomposition only` |

Stage 7 Closure Review begins only after all Stage 7 implementation, delivery, block checkpoints, focused fixes, integration-asset delivery, Integration Harness Preflight, real-stack execution, security/tenant verification, persistence verification, required manual smoke, and cleanup are complete.

This closure review does **not** authorize production implementation changes.

During the read-only closure audit:

- do not edit backend/frontend production code;
- do not edit tests;
- do not fix findings;
- do not stage;
- do not commit;
- do not push;
- do not merge;
- do not change Stage bookkeeping until the closure verdict is determined.

ChatGPT owns:

- closure analysis;
- roadmap/acceptance mapping;
- Stage scope audit;
- architecture/API/database/security/lifecycle review;
- evidence-validity decisions;
- findings and severity;
- final closure verdict.

Codex is not used merely to collect closure evidence.

If closure discovers a production defect:

```text
Verdict = NOT ACCEPTED
```

and ChatGPT prepares a focused implementation-fix contract.

If closure discovers only documentation/bookkeeping drift:

- correct only the affected documentation/bookkeeping;
- do not reopen product implementation unless the documentation drift exposes a real product mismatch.

---

# 2. Current Planning Baseline

At closure-contract preparation time:

```text
origin/main =
294d17317ed0c7428171fc20223da65e7a2cafd1
```

This commit is:

```text
docs(workflow): add integration reliability preflight
```

and Stage 6 is already closed before this planning baseline.

This SHA is only the **planning baseline**.

Do not execute Stage 7 Closure against this SHA.

At closure time:

1. fetch current GitHub `main`;
2. treat that current accepted `origin/main` as the only source of truth;
3. verify all Stage 7 delivery evidence is reachable from it;
4. freeze the closure-audited SHA.

---

# 3. Closure Entry Conditions

Every required row below must pass before substantive closure audit can produce `STAGE CLOSED`.

| Condition | Required result | Evidence |
|---|---|---|
| Stage 6 explicitly closed | `PASS` | `tasks/STAGE_06_CLOSURE_REVIEW.md` |
| Stage 7 decomposition approved | `PASS` | Stage 7 task index/planning evidence |
| `S07-DOC-001` accepted/delivered | `PASS` | PR/SHA |
| `S07-BE-001…007` accepted/delivered | `PASS` | PR/SHA inventory |
| `S07-BE-PHASE-2` | `PASS` | review file + audited SHA |
| `S07-FE-001…005` accepted/delivered | `PASS` | PR/SHA inventory |
| `S07-FE-PHASE-2` | `PASS` | review file + audited SHA |
| `S07-INT-001` integration assets accepted/delivered | `PASS` | PR/SHA |
| Integration Harness Preflight | `PASS` | ChatGPT preflight evidence |
| Windows real-stack Stage 7 runner | `PASS` | final accepted runner evidence |
| Direct API security/tenant matrix | `PASS` | integration evidence |
| Independent DB/private-file oracle | `PASS` | integration evidence |
| Backend restart persistence check | `PASS` | integration evidence |
| Android manual Student smoke | `PASS` | Project Owner evidence |
| Final integration cleanup | `PASS` | cleanup oracle |
| Required focused fixes | `PASS` or justified `N/A` | fix tasks/PRs |
| Current `origin/main` contains final accepted Stage 7 product | `PASS` | SHA |
| All final integration assets/fixes are delivered | `PASS` | SHA/PR |
| Local `main == origin/main` | `PASS` | exact SHAs |
| Ahead/behind | `0/0` | Git output |
| Working tree | `Clean` | Git output |
| Unresolved P1 | `0` | final findings |
| Unresolved P2 | `0` | final findings |

Any failed required condition blocks closure.

Do not mark Stage 7 closed with:

```text
CONDITIONAL PASS
```

or an incomplete smoke/integration result.

---

# 4. Required Closure Git Preflight

Before closure review:

```bash
git switch main
git fetch --prune origin
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
branch = main
HEAD == origin/main
ahead/behind = 0/0
working tree clean
```

Record exact:

```text
Audited origin/main = <sha>
Local main = <sha>
Ahead/behind = 0/0
Working tree = clean
```

If Git state is dirty/divergent:

```text
BLOCKED
```

Do not infer final Stage state from a local task branch.

---

# 5. Authoritative Closure Inputs

At closure time ChatGPT must re-read current `main`:

```text
AGENTS.md
backend/AGENTS.md
frontend/AGENTS.md
tasks/README.md
```

Relevant final synchronized product/technical docs:

```text
docs/01-business-overview.md
docs/02-user-roles.md
docs/03-features.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
```

Stage-specific task/review inputs:

```text
tasks/STAGE_07_TASK_INDEX.md

S07-DOC-001
S07-BE-001
S07-BE-002
S07-BE-003
S07-BE-004
S07-BE-005
S07-BE-006
S07-BE-007
S07-BE-PHASE-2

S07-FE-001
S07-FE-002
S07-FE-003
S07-FE-004
S07-FE-005
S07-FE-PHASE-2

S07-INT-001
```

Also review:

- final current implementation;
- final current tests;
- Backend Phase 2 evidence;
- Frontend Phase 2 evidence;
- Integration Harness Preflight evidence;
- final real-stack integration report;
- API security evidence;
- DB/private-file oracle evidence;
- restart evidence;
- Android manual smoke evidence;
- cleanup evidence;
- all focused fix/delivery records.

Do not rely only on task completion summaries.

---

# 6. Exact Stage 7 Task Inventory

Closure must reconcile the approved pre-closure inventory exactly.

## Documentation alignment

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 1 | `S07-DOC-001` | Student Homework execution contract alignment | `Accepted / Delivered` |

## Backend block

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 2 | `S07-BE-001` | Student answer/submission persistence foundation | `Accepted / Delivered` |
| 3 | `S07-BE-002` | Homework Attempt finalization/deadline engine | `Accepted / Delivered` |
| 4 | `S07-BE-003` | Student Homework read API | `Accepted / Delivered` |
| 5 | `S07-BE-004` | Idempotent Homework Attempt start/resume | `Accepted / Delivered` |
| 6 | `S07-BE-005` | Typed Student answer save/replace | `Accepted / Delivered` |
| 7 | `S07-BE-006` | File-Based Student answer flow | `Accepted / Delivered` |
| 8 | `S07-BE-007` | Idempotent final Homework submit | `Accepted / Delivered` |
| 9 | `S07-BE-PHASE-2` | Backend block read-only review | `PASS` |

## Frontend block

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 10 | `S07-FE-001` | Student Homework read foundation | `Accepted / Delivered` |
| 11 | `S07-FE-002` | Attempt start/resume shell | `Accepted / Delivered` |
| 12 | `S07-FE-003` | Eight non-file answer editors | `Accepted / Delivered` |
| 13 | `S07-FE-004` | File answer UX | `Accepted / Delivered` |
| 14 | `S07-FE-005` | Submit/finalization UX | `Accepted / Delivered` |
| 15 | `S07-FE-PHASE-2` | Frontend block read-only review | `PASS` |

## Integration

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 16 | `S07-INT-001` | Real-Stack Student Homework E2E | `Accepted / Delivered / PASS` |

No approved Stage 7 task may remain:

```text
Approved
In Progress
Implementation Complete but not Accepted
Accepted but not Delivered
NOT ACCEPTED
BLOCKED
```

at final closure.

Focused fix tasks, if any were required, must also be listed in the Stage index and shown as accepted/delivered.

---

# 7. Roadmap Stage Goal

Authoritative roadmap Stage:

```text
Stage 7 — Student Homework and Submission Flow
```

Roadmap goal:

> Allow Students to complete assigned homework and create protected attempt/submission records.

Business value:

> This stage produces the Student’s real home-task data instead of only Teacher-authored content.

Closure must verify that Stage 7 delivers real Student Homework execution while preserving the deliberate boundary that:

```text
Stage 7 = capture/freeze Student Homework work
Stage 8 = Blitz
Stage 9 = checking/scoring/official Homework score
Stage 10 = final Topic result
```

---

# 8. Exact Roadmap Acceptance Criterion

The Stage 7 roadmap acceptance criterion is:

> A Student can complete up to three valid Homework attempts while the system preserves each attempt and enforces deadline, timezone, relationship, institution, and file-limit rules.

Closure cannot produce:

```text
STAGE CLOSED
```

unless this complete criterion is supported by:

- backend implementation;
- frontend implementation;
- Backend Phase 2;
- Frontend Phase 2;
- real-stack Windows integration;
- direct API security/tenant verification;
- DB/private-file persistence oracle;
- restart verification;
- Android manual smoke.

---

# 9. Roadmap Required-Test Matrix

Closure maps every Stage 7 roadmap required test to final accepted evidence.

| Roadmap required test | Closure result | Implementation evidence | Verification evidence |
|---|---|---|---|
| Assigned Student can start | `Pending` | BE-003/004, FE-001/002 | BE Phase 2 + FE Phase 2 + Integration |
| Unassigned Student blocked | `Pending` | BE-003/004 | Backend security tests + real API matrix |
| Exactly three normal Homework attempts available | `Pending` | BE-001/004, FE-001/002 | Backend tests + Windows flow + DB oracle |
| Fourth normal Homework attempt blocked | `Pending` | BE-004 | Backend tests + real API exhaustion check |
| Deadline blocks invalid start/submission | `Pending` | BE-002/004/005/006/007 | Backend lifecycle tests + deadline integration |
| Submitted attempt immutable to Student | `Pending` | BE-005/006/007, FE-003/004/005 | Backend tests + terminal UI + real API |
| Second attempt creates separate history | `Pending` | BE-004 | Windows attempts #1/#2 + DB oracle |
| Parent cannot submit | `Pending` | Student middleware/API | backend role tests + real API wrong-role matrix |
| Cross-institution Student blocked | `Pending` | tenant-safe API/persistence | backend tests + integration security |
| 15 MB/lower-institution file validation/protection | `Pending` | BE-006, FE-004 | focused tests + real file integration |
| Desktop/mobile permission consistency | `Pending` | FE-001…005 | FE Phase 2 + Windows + Android smoke |

Every row must end:

```text
PASS
```

No `Not verified` row is acceptable.

---

# 10. Stage 7 Included-Scope Audit

Closure must verify every included roadmap surface is present.

## 10.1 Student Homework entry

Student desktop/mobile can see appropriate:

```text
assigned Homework
deadline
three-attempt availability
completion state
```

Stage 7 implementation may integrate Homework entry under Student Topic detail rather than introducing an unrelated dashboard architecture.

The final behavior must still satisfy the roadmap capability.

## 10.2 Attempt start

Before/at start, Student receives server-authoritative:

```text
Homework instructions
normal attempts = 3
used/remaining
deadline
safe Questions
current in-progress Attempt if present
```

Backend validates:

```text
active authenticated Student
active Institution
frozen assignment
Homework lifecycle
deadline
attempt capacity
```

## 10.3 Answering

Support all nine types:

1. Single Choice
2. Multiple Choice
3. True / False
4. Short Written
5. Open Written
6. File Based
7. Matching
8. Ordering
9. Fill in the Blank

Desktop and mobile must obey identical backend business/security rules.

## 10.4 File answer

Allowed submission formats:

```text
PDF
DOCX
PPT
PPTX
```

Hard platform maximum:

```text
15 MiB / Stage product 15 MB contract as implemented
```

Effective Institution limit may be lower.

Backend content inspection is authoritative.

Private storage required.

## 10.5 Submission/finalization

A valid explicit final Submit freezes the Attempt and persisted answers.

Automatic deadline/Teacher-close finalization freezes the existing saved answer set.

No never-started Student receives a fabricated Attempt.

## 10.6 Attempt history

Exactly:

```text
3 normal Attempts maximum
separate Attempt rows
no overwrite of submitted Attempt
no Attempt #4
no Homework Blitz exception
```

---

# 11. Locked Stage 7 Contract Clarifications

`S07-DOC-001` intentionally removes ambiguities from older generic wording.

Closure must verify final docs and implementation agree on the following.

## 11.1 Homework terminal execution state

Stage 7 Homework uses:

```text
submitted
```

for:

- explicit Student submit;
- deadline auto-finalization;
- Teacher-close auto-finalization.

Do not require:

```text
timed_out_finalized
```

for Homework.

That status remains Blitz-oriented.

## 11.2 Explicit Student Submit

```text
status = submitted
submitted_at = submit instant
finalized_at = submit instant
locked_at = submit instant
reason = student_submit
```

## 11.3 Deadline auto-finalization

```text
status = submitted
submitted_at = null
finalized_at = exact deadline
locked_at = exact deadline
reason = homework_deadline_auto_submit
```

## 11.4 Teacher close before deadline

```text
status = submitted
submitted_at = null
finalized_at = close instant
locked_at = close instant
reason = task_closed_auto_finalize
```

## 11.5 Deadline wins after/equal deadline

Teacher close must not rewrite a due Attempt from:

```text
homework_deadline_auto_submit
```

to:

```text
task_closed_auto_finalize
```

## 11.6 No fabricated unanswered rows

Unanswered Questions:

```text
no attempt_answers row
```

Stage 7 does not fabricate zero-value answer rows.

---

# 12. Assignment / Historical Access Audit

Stage 7 Homework execution assignment is based on the frozen:

```text
assessment_students
```

recipient snapshot.

Closure must verify final implementation does **not** make current:

```text
group_student_memberships
```

the authoritative Student Homework execution scope.

Required behavior:

- current Group membership removal does not erase frozen assigned Homework history;
- own historical Attempt remains readable;
- own historical Student submission remains protected/downloadable;
- another Student cannot access it;
- foreign Institution cannot access it.

This does not change the earlier Stage 5 Student Topic membership contract.

---

# 13. One In-Progress Attempt Audit

Required DB invariant:

```text
at most one in_progress Attempt
per Homework assessment + Student
```

Closure verifies:

- PostgreSQL partial unique constraint exists;
- application locks compose with it;
- Start races cannot create two in-progress Attempts;
- no implementation relies only on frontend duplicate suppression.

---

# 14. Three-Attempt Policy Audit

Exactly:

```text
attempt_number ∈ {1,2,3}
```

Rules:

- no Attempt #4;
- submitted Attempts remain historical;
- Start creates next sequential Attempt;
- no gap backfill;
- current in-progress Attempt is resumed;
- no Institution Admin/Teacher override of the normal Homework attempt count.

Frontend must not become the authoritative counter.

---

# 15. Start / Resume Audit

Public Start:

```text
POST /api/v1/student/homework/{homework}/attempts
```

High-risk operation requires:

```text
Idempotency-Key
```

Required behavior:

```text
no in-progress + capacity -> create -> 201
existing in-progress -> same Attempt -> 200
exhausted -> 409 attempts_exhausted
```

Frontend confirmed Resume:

```text
direct route navigation
no redundant POST
```

Backend remains authoritative if state changed.

---

# 16. Start Idempotency Audit

Durable scope:

```text
institution
user
operation = student.homework.attempt.start
idempotency key
```

Required:

- same key/same request => same logical result;
- uncertain client retry uses the same key;
- different semantic request using same key => `idempotency_key_reused`;
- failed Start does not leave a committed incomplete success record;
- separate Start operation scope does not conflict with Submit using the same UUID value.

Any duplicate Attempt caused by same-key replay is a closure-blocking defect.

---

# 17. First Official Attempt / Result-Pair Lock Audit

For the first global Attempt on designated official Homework:

```text
topic_result_pairs.locked_at
```

must become:

```text
Attempt.started_at
```

atomically with first Attempt creation.

Closure verifies:

- `cohort_snapshotted_at != null`;
- Student belongs to persisted official cohort;
- official pair meaning is locked before Attempt insert becomes durable;
- rollback cannot leave pair locked with missing first Attempt;
- later Attempts preserve original pair-lock timestamp;
- practice Homework does not mutate official pair;
- `blitz_assessment_id` may remain null until Stage 8.

---

# 18. Student-Safe Question Privacy Audit

No Student Stage 7 success response/UI may expose:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
Teacher configuration object
client_key
```

Multiple Choice may expose:

```text
max_selections
```

without correct-option identities.

Matching left/right lists must not encode correct pairing by frontend assumption.

Ordering display order must not be presented as correct order.

Any answer-key leak:

```text
P1
```

and Stage closure is blocked.

---

# 19. Typed Answer Persistence Audit

Closure verifies normalized persistence for:

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

No generic authoritative answer JSON fallback.

Every Student-saved answer must remain:

```text
checking_status = pending

awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Stage 7 does not score answers.

---

# 20. Non-File Answer Mutation Audit

Endpoint:

```text
PUT /student/attempts/{attempt}/answers/{question}
```

Closure verifies:

- own assigned Student only;
- exact Question scope;
- all eight non-file payloads;
- replace semantics;
- clear semantics only where approved;
- semantic no-op avoids timestamp churn;
- terminal Attempt rejects write;
- deadline prevents post-deadline write;
- no score/checking side effects.

Frontend:

```text
explicit per-Question Save
```

No autosave.

---

# 21. File Answer Security Audit

Required:

```text
PUT same answer endpoint
multipart/form-data
type=file_based
one file
```

Formats:

```text
pdf/docx/ppt/pptx
```

Backend:

- does binary/signature inspection;
- does not trust client MIME;
- enforces effective size;
- stores private;
- uses server storage key;
- protects replacement cleanup.

Frontend local validation is UX only.

---

# 22. File Replacement Integrity Audit

Closure verifies replacement preserves:

```text
AttemptAnswer ID
AnswerFile ID
File ID
```

and changes authoritative stored blob metadata.

Required:

- new blob cleaned on failed/rolled-back replacement;
- old blob deleted best-effort after successful commit;
- DB never points at uncommitted/failed blob;
- exact-binary server no-op does not corrupt identity;
- no public URL/storage key shown to Student.

---

# 23. Protected Student Submission Download Audit

Route:

```text
GET /api/v1/files/{file}/download
```

Stage 7 Student submission access:

```text
Student owner only
```

Teacher direct Student submission download:

```text
404
```

until Stage 9.

Other Student/foreign Institution:

```text
404
```

Owner historical download remains valid after Attempt finalization/current Group membership loss.

Response security:

```text
attachment
private, no-store
nosniff
canonical supported MIME
```

No public storage route.

---

# 24. Deadline Authority Audit

Only server/UTC authority may enforce deadline.

Homework deadline source:

```text
homework_assignments.deadline_at
```

Homework `assessment_attempts.deadline_at` remains:

```text
null
```

Boundary:

```text
observed server instant >= deadline
=> deadline reached
```

Must be applied consistently to:

```text
Student Homework reads
Attempt Start
answer save
file answer upload
Submit
Teacher close
Scheduler
```

Scheduler latency must never allow a post-deadline Student mutation.

Device clock/timezone may format display only.

---

# 25. Request-Path Reconciliation Audit

Relevant Student reads must not expose stale editable state merely because Scheduler has not run.

Closure verifies request-path reconciliation:

- only after proper authorization;
- scoped to assigned/owned target;
- calls same authoritative deadline engine;
- does not fabricate Attempts;
- cannot be abused to mutate a foreign inaccessible Homework.

---

# 26. Scheduler Audit

Required scheduled command:

```text
homework:reconcile-deadlines
```

Expected scheduling:

```text
everyMinute
withoutOverlapping(5)
```

Correctness must not depend on `withoutOverlapping`.

Candidate iteration:

```text
keyset/bounded
active
due
has in-progress Attempt
```

Per candidate authoritative locked re-check.

One candidate failure must not prevent later candidates from processing.

Second reconciliation is idempotent.

---

# 27. Teacher Close Integration Audit

Stage 6's temporary:

```text
reject close when in-progress Attempt exists
```

must be replaced.

Stage 7 final behavior:

- close finalizes existing in-progress Attempts atomically;
- deadline takes precedence if already due;
- saved answers preserved;
- terminal Attempts remain unchanged;
- never-started Students get no Attempt.

This is a deliberate Stage 6 -> Stage 7 behavior evolution.

---

# 28. Final Submit Audit

Endpoint:

```text
POST /api/v1/student/attempts/{attempt}/submit
```

Requires:

```text
Idempotency-Key
{}
```

Explicit Submit may freeze:

```text
all answers
some answers
zero answers
```

No completeness validation.

Closure verifies:

- only in-progress Attempt transitions;
- target Attempt locks;
- no answer fabrication;
- returned terminal resource is Student-safe;
- subsequent different-key Submit is rejected;
- same-key replay remains successful.

---

# 29. Submit Idempotency Audit

Scope:

```text
institution
user
operation = student.homework.attempt.submit
key
```

Required:

- same key/same Attempt => 200 replay;
- uncertain frontend retry => same key;
- success record committed atomically with finalization;
- different key after terminal => `attempt_not_editable`;
- same UUID may also exist under Start operation because operation separates scope;
- no timestamp/reason rewrite on replay.

---

# 30. Submit vs Answer/File Concurrency Audit

Required serialization:

## Answer saves first

Saved answer is included in final frozen Attempt.

## Submit wins first

Later answer/file mutation sees terminal Attempt and fails.

For file upload rejected after Submit lock:

- staged new blob compensation must clean it.

No partial state that claims Submit while a later mutation is still authoritative.

---

# 31. Submit vs Deadline Audit

Capture Submit decision time after required locks.

Required:

```text
submittedAt < deadline
=> Student explicit Submit may win
```

```text
submittedAt >= deadline
=> deadline wins
```

Equality belongs to deadline.

If deadline wins:

```text
reason = homework_deadline_auto_submit
submitted_at = null
finalized_at = deadline
```

No successful Submit idempotency record for the rejected explicit logical Submit.

---

# 32. Submit vs Teacher Close Audit

Required outcomes:

## Submit locks/finalizes first before deadline

```text
student_submit preserved
```

Later Teacher close does not rewrite Attempt.

## Teacher close finalizes first

```text
task_closed_auto_finalize
```

New Submit cannot overwrite.

## Same previously successful idempotency-key replay

May still replay logical success according to completed record contract.

No reason/timestamp churn.

---

# 33. Frontend Homework Read Definition-of-Done

Closure verifies final Student frontend:

- separate Student Homework typed domain;
- separate Student safe Question domain;
- strict DTO parsing;
- Topic Homework section;
- Homework detail;
- desktop/mobile;
- server-authoritative attempts/status;
- Institution-timezone formatting;
- no score;
- no client deadline authority.

---

# 34. Frontend Attempt Start/Resume Definition-of-Done

Required:

- secure UUID-v4 generator;
- no new dependency solely for UUID;
- Start 201=create;
- Start 200=resume race;
- confirmed current Attempt Resume avoids POST;
- canonical nested Attempt route;
- direct-entry hierarchy checks;
- same-key uncertain Start retry;
- no optimistic attempt counters.

---

# 35. Frontend Answer Editors Definition-of-Done

Eight non-file editors must work on desktop/mobile.

Required:

```text
explicit Save
semantic dirty/no-op
typed drafts
typed payloads
safe local validation
partial matching/ordering/fill
exact written text
uncertain PUT reconciliation
unsaved-work guard
```

No correct-answer inference.

---

# 36. Frontend File UX Definition-of-Done

Required:

```text
existing file_picker
explicit upload
multipart production transport
local safe extension/size validation
server binary authority
first upload
same-ID replacement
uncertain same-file retry
protected Open
protected Save As
terminal historical download
navigation protection
```

No file clear/delete.

No duplicate protected download stack.

---

# 37. Frontend Submit Definition-of-Done

Required:

- Submit only against confirmed clean in-progress Attempt;
- dirty drafts block;
- pending selected file blocks;
- active/uncertain answer/file operation blocks;
- zero answered Questions does not block;
- confirmation displays confirmed saved/unanswered count;
- no auto-save-all;
- same-key uncertain Submit retry;
- route-level operation gate freezes new mutations;
- authoritative terminal Attempt adopted immediately;
- deadline/close auto-finalization shown distinctly;
- no score/checking.

---

# 38. Frontend Navigation / Stale Async Audit

Closure verifies stale completion cannot:

- navigate from obsolete Start;
- publish another Student's Homework;
- overwrite newer Attempt;
- apply old answer save;
- apply old file upload;
- Open/Save stale replaced File;
- adopt obsolete Submit result.

Route leave priority:

```text
submitting
submit uncertain
answer/file uncertain
dirty/pending local work
clean
```

No automatic mutation on leave.

---

# 39. Backend Phase 2 Closure Evidence

Populate at closure.

| Field | Value |
|---|---|
| Review | `S07-BE-PHASE-2` |
| Required | `Yes` |
| Audited SHA | `<sha>` |
| Verdict | `PASS required` |
| Findings | `<P1/P2/P3>` |
| Full backend suite | `<result>` |
| Pint | `<result>` |
| lint/static-equivalent | `<result>` |
| diff check | `<result>` |
| Later production change after checkpoint | `<none / description>` |
| Evidence still valid | `<yes/no>` |
| Additional rerun needed | `<none / exact commands>` |
| Additional result | `<N/A/result>` |

Closure reuses valid Backend Phase 2 evidence.

Do not rerun the full backend suite during closure solely because closure started.

---

# 40. Frontend Phase 2 Closure Evidence

Populate at closure.

| Field | Value |
|---|---|
| Review | `S07-FE-PHASE-2` |
| Required | `Yes` |
| Audited SHA | `<sha>` |
| Verdict | `PASS required` |
| Findings | `<P1/P2/P3>` |
| Full frontend suite | `<result>` |
| Analyze | `<result>` |
| Full format check | `<result>` |
| Windows debug build | `<result>` |
| Android debug build | `<result>` |
| diff check | `<result>` |
| Later production change after checkpoint | `<none / description>` |
| Evidence still valid | `<yes/no>` |
| Additional rerun needed | `<none / exact commands>` |
| Additional result | `<N/A/result>` |

Do not rerun full frontend tests/builds during closure when accepted evidence remains valid.

---

# 41. Integration Closure Evidence

Populate from final `S07-INT-001`.

| Integration boundary | Required result |
|---|---|
| Integration assets delivered | `PASS` |
| Harness Preflight | `PASS` |
| Runtime guard | `PASS` |
| Deterministic Seeder | `PASS` |
| Test-file verifier | `PASS` |
| Windows production UI flow | `PASS` |
| Nine Question types | `PASS` |
| File upload/replacement/download | `PASS` |
| First official pair lock | `PASS` |
| Three-attempt history/exhaustion | `PASS` |
| Start idempotency | `PASS` |
| Answer no-op | `PASS` |
| Submit idempotency | `PASS` |
| Deadline read reconciliation | `PASS` |
| Scheduler reconciliation | `PASS` |
| Teacher close finalization | `PASS` |
| Deadline-vs-close precedence | `PASS` |
| Tenant/ownership/privacy matrix | `PASS` |
| DB/private-file oracle | `PASS` |
| No scoring/checking | `PASS` |
| Backend restart persistence | `PASS` |
| Android manual smoke | `PASS` |
| Final cleanup | `PASS` |

No missing required integration phase may be treated as implicit PASS.

---

# 42. Integration Harness Reliability Closure Audit

Closure must verify the final accepted integration evidence came from the final accepted harness.

Required:

- Harness Preflight occurred **before** first full Stage 7 runner;
- stable keys/IDs/scoped selectors;
- no ambiguous global text matching on repeated editor controls;
- condition-based bounded waits;
- hit-testability before taps where required;
- no arbitrary sleeps as correctness synchronization;
- deterministic file fixtures;
- deterministic idempotency-key queue;
- tenant-safe deterministic seeding;
- independent DB oracle;
- private-file oracle;
- cleanup verified;
- material runner failure classified as:
  - production;
  - harness;
  - environment
  before a fix.

A green result from a known-flaky/unreliable final harness is not sufficient closure evidence.

---

# 43. Real-Stack End-to-End Audit

Closure verifies the final accepted production candidate completed this complete chain:

```text
Flutter Student UI
-> GoRouter
-> Student Riverpod/application state
-> typed repository/DTO
-> configured Dio
-> Laravel/Sanctum
-> PostgreSQL
-> private file storage
```

Required primary real-stack scenarios:

- Student login;
- assigned Homework read;
- first Attempt Start;
- all eight non-file answer saves;
- file content rejection;
- file upload;
- file replacement;
- protected file Open/Save;
- persisted Resume;
- explicit Attempt #1 Submit;
- zero-answer Attempt #2 Submit;
- Attempt #3 Submit;
- fourth attempt blocked;
- terminal read-only state.

The UI appearing correct without DB/API evidence is not enough.

---

# 44. Persistence / Database Definition-of-Done

Closure verifies final authoritative persistence includes:

```text
assessment_attempts
attempt_answers
typed answer child tables
files
answer_files
idempotency_records
topic_result_pairs
assessment_students
```

Required invariants:

- tenant-safe FKs;
- one in-progress partial unique;
- at most three normal Attempts;
- normalized answer tables;
- no generic JSON fallback;
- no scoring;
- stable file replacement identity;
- official pair lock stable;
- durable idempotency.

---

# 45. Authorization and Tenant Isolation Audit

Required PASS:

- unauthenticated denied;
- wrong role denied;
- Parent cannot submit;
- same-Institution unassigned Student denied;
- cross-Institution Student denied;
- foreign direct Homework ID denied;
- foreign Attempt ID denied;
- foreign Question/child ID cannot widen scope;
- other Student submission File denied;
- Teacher Student-submission File denied in Stage 7;
- Student owner protected File allowed;
- historical frozen assignment remains safe.

Knowing a UUID must not grant access.

Backend authorization remains authoritative; frontend visibility is not authorization.

Any unresolved Tenant/access defect:

```text
P1
```

and closure blocked.

---

# 46. Error Contract Audit

Expected shared envelope:

```text
message
code
errors
```

Relevant Stage 7 codes include:

```text
resource_not_found
validation_failed

task_not_active
task_closed
task_archived
deadline_passed

assessment_not_assigned
attempts_exhausted
attempt_not_editable
selection_limit_exceeded
idempotency_key_reused
business_conflict

unsupported_file_type
file_too_large
file_upload_failed
file_not_available
```

Closure verifies no raw:

- SQL;
- stack trace;
- class name;
- storage path;
- bearer token;
- answer key;
- foreign resource existence.

---

# 47. Idempotency Record Audit

Closure verifies durable records only for approved high-risk operations:

```text
student.homework.attempt.start
student.homework.attempt.submit
```

Required:

```text
institution/user/operation/key scope
SHA-256 request fingerprint
completed result metadata
no cross-operation collision
no committed incomplete failure records
```

Ordinary answer PUT/file PUT:

```text
no Idempotency-Key
```

Frontend retry semantics must match operation type.

---

# 48. Evidence Validity / Minimum Rerun Policy

Stage Closure reuses valid evidence.

Do **not** rerun:

```text
full backend suite
full frontend suite
standalone Windows build
standalone Android build
full Stage 7 real-stack runner
```

merely because closure begins.

Fresh PASS evidence remains valid until a later change materially affects the surface it proved.

ChatGPT decides evidence validity.

Default:

| Later change | Evidence impact |
|---|---|
| Docs/bookkeeping-only | Product evidence remains valid |
| Comment/rename-only no behavior | Usually remains valid |
| Narrow test-only strengthening | Production evidence remains valid; run affected tests if needed |
| Narrow feature production fix | Preserve unrelated evidence; rerun focused checks + affected integration path |
| Student router/session/client shared fix | May invalidate Frontend Phase 2 + integration routing/session path |
| Schema/authorization/idempotency fix | Normally invalidates Backend Phase 2 affected scope + security/integration/oracle |
| File storage/download shared fix | Invalidates affected backend/file regression + frontend file regression + file integration |
| Submit/Attempt lifecycle shared fix | Invalidates relevant Backend Phase 2 concurrency/lifecycle + frontend Submit state + affected integration |
| Required command previously failed | That command must eventually pass |
| Integration scenario failed before later phases | Rerun enough to prove complete final scenario |

Do not preserve evidence that a later change materially invalidated.

Do not rerun broad checks by habit.

---

# 49. Production Fixes After Checkpoints

If any production fix occurred after either Phase 2 checkpoint:

Closure must record:

```text
fix task
PR/SHA
affected surface
evidence invalidated
evidence rerun
final result
```

Examples:

## Narrow file metadata UX fix

May not invalidate Backend Phase 2.

May require:

- focused frontend file tests;
- relevant integration file path.

## Backend idempotency/locking fix

Normally requires:

- focused backend Start/Submit/concurrency tests;
- corresponding DB/idempotency integration;
- possibly refreshed Backend Phase 2 full-suite evidence if ChatGPT judged it materially invalidated.

## Shared router/session fix

May require:

- refreshed Frontend Phase 2;
- Windows/Android route/session integration path.

Closure must reason explicitly, not assume.

---

# 50. Regression Audit — Stage 6 Teacher Homework

Stage 7 must preserve Stage 6 Teacher authoring except deliberate close behavior evolution.

Required unchanged capabilities:

- Homework read/create/edit;
- all-nine Question authoring;
- recipient snapshot;
- official Homework designation;
- result-pair null Blitz support;
- scoring-content lock after Student activity;
- archive/history;
- Topic lifecycle integration.

Deliberate Stage 7 change:

```text
Teacher close with in-progress Homework Attempts
```

now auto-finalizes existing in-progress Attempts rather than rejecting close.

This must not be classified as a Stage 6 regression.

---

# 51. Regression Audit — Stage 5 Files

Stage 7 shared file changes must not break:

- Teacher Learning Material upload/replace;
- protected Learning Material download;
- Student Learning Material Open/Save As;
- security headers/parser;
- local native Open/Save behavior.

Stage 7 Student submission uses the same protected download route safely without changing Learning Material authorization.

---

# 52. Regression Audit — Stage 1–4

Verify no blocking regression to:

- authentication/session;
- password-change gate;
- role routing;
- Institution lifecycle;
- Institution Admin users/settings;
- Groups/memberships;
- Parent-Student relations;
- Topic access.

Broad previous-Stage E2E need not be rerun at closure if checkpoint/integration evidence already demonstrates no affected regression and no later shared change invalidated it.

---

# 53. Stage 8 Compatibility Audit

Stage 7 must leave Blitz implementation space intact.

Required:

- no public Blitz execution implemented;
- `timed_out_finalized` remains available for Blitz;
- Homework Attempt deadline-at field is not misused as Blitz timer;
- official result pair may remain:
  ```text
  homework_assessment_id != null
  blitz_assessment_id = null
  locked_at != null
  ```
- Stage 8 can later attach the absent Blitz without replacing locked Homework/cohort meaning.

No fake Blitz created merely to satisfy Stage 7.

---

# 54. Stage 9 Compatibility / Scope Boundary Audit

Stage 7 must **not** implement Stage 9 result behavior.

Forbidden Stage 7 production behavior:

```text
automatic answer checking
manual Teacher marking/review
awarded_points mutation
Attempt normalized score
scoring_completed_at
official Homework Attempt selection
official Homework score
score release
Teacher Student-submission review/download
```

Stage 7 may persist:

```text
checking_status = pending
possible_points snapshot
```

as structural readiness.

No Student Stage 7 UI score.

Any actual scoring/checking introduced early is scope leakage and blocks closure unless formally reapproved.

---

# 55. Stage 10 Compatibility Audit

Stage 7 must not compute:

```text
Homework-Blitz difference
Topic final score
understanding category
Topic Result closure
```

No final result release.

Those remain future Stages.

---

# 56. Roadmap Submission Status Reconciliation

The roadmap lists generic Student-level status concepts including future checking/result states.

Closure must interpret them consistently with final synchronized Stage 7 docs:

Stage 7 actively produces/uses:

```text
not_started
in_progress
submitted
```

and safely reads forward-compatible:

```text
waiting_for_teacher_review
checked
```

when later stages eventually produce them.

For Stage 7 Homework automatic finalization:

```text
submitted
```

is the terminal execution state.

Do not require a Homework-specific `expired/time ended` Attempt status when final Stage 7 contract intentionally records deadline auto-finalization as `submitted + homework_deadline_auto_submit`.

Final docs must no longer contradict this behavior.

---

# 57. Frontend Desktop / Mobile Closure Audit

Required Student capabilities on both supported surfaces:

```text
Homework read
Attempt Start/Resume
eight non-file answer edits
file answer UX
Submit/finalization UX
terminal read-only state
```

Full production file flow is automated on Windows.

Android required manual smoke proves representative Student execution through real stack.

Business/security rules remain server-identical.

No frontend surface may create a weaker security rule.

---

# 58. Accessibility / Responsive Closure Audit

Reuse Frontend Phase 2 evidence.

Required Stage 7 interactive surfaces are usable with:

- semantic headings;
- explicit status text;
- keyboard on desktop;
- touch on mobile;
- visible progress;
- clear errors;
- scoped Save/Discard/Clear controls;
- accessible file picker/upload;
- Submit confirmation;
- unsaved/uncertain navigation guards;
- no horizontal overflow at supported widths/text scaling.

No material accessibility dead-end may remain.

---

# 59. Project Owner Manual Smoke Review

The required Stage 7 manual smoke is defined inside `S07-INT-001`.

Required:

```text
Android real-stack Student Homework smoke = PASS
```

Minimum accepted flow:

1. real Student login;
2. open dedicated Stage 7 mobile Homework;
3. Start Attempt;
4. save representative answers;
5. view Submit confirmation with unanswered count;
6. Submit;
7. observe terminal `Submitted by you`;
8. return to Homework and observe refreshed attempt count/state;
9. DB oracle verifies the manual-smoke Attempt.

Closure records:

```text
Manual smoke status: PASS
Confirmed by: Project Owner
Date: <date>
Device/target: <safe description>
Evidence: <reference>
```

Do not claim PASS if the Project Owner did not actually run required smoke.

---

# 60. Integration Cleanup Closure Audit

`S07-INT-001` final cleanup must have verified:

```text
zero manifest-owned Stage 7 DB fixture rows
zero manifest-owned Stage 7 private blobs
zero generated local Stage 7 test files
temporary container scripts removed
unrelated sentinel state preserved
```

The external dedicated private named volume may remain provisioned unless Project Owner chooses to remove it after evidence.

Closure cares that Stage 7 owned test data/blobs do not pollute normal project state.

---

# 61. Documentation Synchronization Audit

Closure must compare final behavior against final synchronized:

```text
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
```

At minimum final docs must agree on:

- three Homework attempts;
- frozen assignment;
- create/resume;
- one in-progress;
- Start/Submit idempotency;
- answer persistence;
- file privacy/limits;
- Homework deadline semantics;
- Teacher close auto-finalization;
- `submitted` automatic-finalization state;
- Stage 7/9 scoring boundary;
- official pair first-activity lock;
- Stage 8 null Blitz compatibility.

Documentation contradiction that can mislead future Stage implementation blocks closure until documentation is corrected.

---

# 62. Stage Index / Task Bookkeeping Audit

`tasks/STAGE_07_TASK_INDEX.md` must reflect:

- exact 16 pre-closure Stage items;
- all implementation tasks accepted/delivered;
- both Phase 2 reviews PASS;
- Integration PASS;
- any focused fix tasks;
- final audited SHAs/PRs as appropriate;
- no task incorrectly left `Approved`/`In Progress`.

If the Stage index did not exist before closure bookkeeping, it must be created from the approved/delivered inventory before final closure delivery.

Do not invent tasks not actually approved/delivered.

---

# 63. `tasks/README.md` Stage Status Audit

Before closure bookkeeping:

```text
Stage 7 may still be In Progress
```

After final `STAGE CLOSED` verdict and bookkeeping delivery:

```text
Stage 7 = Closed / PASS
```

must be reflected according to the current task README's established Stage-status format.

Do not alter historical Stage 0–6 evidence to retrofit newer workflow wording.

---

# 64. Closure Read-Only Diff Review

Before verdict, inspect the complete Stage 7 delivered range:

```text
<Stage 7 implementation base>...origin/main
```

Distinguish:

- product code;
- tests;
- docs;
- integration assets;
- focused fixes;
- bookkeeping.

Verify:

- every production change maps to approved Stage 7 scope/fix;
- no hidden Stage 8/9/10 feature;
- no unexpected dependency/platform change;
- no secrets;
- no committed E2E generated binaries;
- no private-file fixture blob;
- no temporary debug route;
- no test weakening;
- no broad unrelated refactor;
- no unresolved TODO/FIXME hiding required Stage 7 behavior.

---

# 65. Closure Findings Severity

Use:

## P1

Security, Tenant isolation, privacy, data corruption/loss, secret/private-file exposure, answer-key leak, or core public-contract breach.

Examples:

- another Student's Attempt/file readable;
- cross-Institution access;
- correct answers exposed;
- same-key retry causes duplicate Attempt;
- private submission publicly reachable;
- Submit/data corruption.

Any P1:

```text
NOT ACCEPTED
```

## P2

Material functionality/architecture/lifecycle/integration/regression defect.

Examples:

- Attempt #4 possible;
- deadline semantics wrong;
- Teacher close overwrites deadline reason;
- one Question type broken;
- file replacement changes File ID;
- frontend loses unsaved state incorrectly;
- Submit requires all answers;
- Stage 9 scoring leaked;
- checkpoint/integration required evidence invalid/missing.

Any P2:

```text
NOT ACCEPTED
```

## P3

Non-blocking maintainability/clarity/test-quality issue.

Default final Stage 7 closure target:

```text
P1=0
P2=0
P3=0
```

Record P3 explicitly if intentionally deferred.

---

# 66. Findings Table

Populate at execution.

| ID | Severity | Finding | Evidence | Blocks closure? | Required action |
|---|---|---|---|---|---|
| `<S07-CLOSE-01>` | `<P1/P2/P3>` | `<finding>` | `<source/evidence>` | `<Yes/No>` | `<focused correction>` |

If none:

```text
No findings.

P1 = 0
P2 = 0
P3 = 0
```

---

# 67. Closure Verdict

Choose exactly:

```text
STAGE CLOSED
```

or:

```text
NOT ACCEPTED
```

`STAGE CLOSED` requires all:

- closure entry gate passes;
- exact task inventory reconciled;
- roadmap acceptance criterion passes;
- every required roadmap test has evidence;
- Backend Phase 2 evidence is valid;
- Frontend Phase 2 evidence is valid;
- S07-INT-001 is PASS on final accepted product;
- Integration Harness Preflight PASS;
- Windows real-stack PASS;
- Android manual smoke PASS;
- DB/private-file oracle PASS;
- restart persistence PASS;
- cleanup PASS;
- authorization/Tenant/privacy PASS;
- no answer-key leakage;
- Stage 8/9/10 boundaries preserved;
- final documentation synchronized;
- current `origin/main` contains complete accepted Stage result;
- P1=0;
- P2=0.

Do not close Stage on:

```text
PARTIAL PASS
CONDITIONAL PASS
integration skipped
manual smoke not run
cleanup not verified
```

when these are required.

---

# 68. If Closure Is NOT ACCEPTED

If closure finds a production defect:

1. preserve closure evidence;
2. record finding;
3. create focused fix contract;
4. Codex implements/focused-verifies only that fix;
5. Project Owner delivers it;
6. ChatGPT determines evidence invalidation;
7. rerun minimum sufficient affected checkpoint/integration evidence;
8. every previously failing required command/path must pass;
9. repeat closure read-only review on final accepted `main`.

If closure finds only documentation/bookkeeping drift:

- correct only that documentation/bookkeeping;
- verify diff;
- deliver;
- re-check current main;
- do not rerun product verification unless the change invalidates it.

No closure-time opportunistic refactor.

---

# 69. Closure Bookkeeping After Read-Only PASS

Only after the read-only audit establishes that Stage 7 qualifies for closure, prepare the closure/documentation bookkeeping.

Expected affected files:

```text
tasks/STAGE_07_CLOSURE_REVIEW.md
tasks/STAGE_07_TASK_INDEX.md
tasks/README.md
```

Modify other product docs only if closure identified genuine synchronization drift not already handled by `S07-DOC-001`.

Do not modify production code in the closure bookkeeping change.

---

# 70. Closure Bookkeeping Required State

`tasks/STAGE_07_CLOSURE_REVIEW.md` must be updated with actual:

```text
review date
audited origin/main
local main
ahead/behind
working-tree state
task delivery evidence
Backend Phase 2 evidence
Frontend Phase 2 evidence
Integration evidence
manual smoke evidence
cleanup evidence
findings counts
final verdict
```

`tasks/STAGE_07_TASK_INDEX.md` must show final task/review/integration states.

`tasks/README.md` must show Stage 7 closed according to established format.

No placeholder `<sha>`/`Pending` remains in the final delivered closure record.

---

# 71. Closure Bookkeeping Verification

Before delivery of closure-only changes:

```bash
git diff --check
git status --short
```

Review closure diff.

Required:

```text
only intended task/docs bookkeeping files
no production source
no test source unless separately approved
no dependency/lock/platform files
no generated artifacts
no secrets
```

If repository has markdown/doc-focused validation commands, run only the relevant established checks.

Do not rerun full backend/frontend/integration for closure-only bookkeeping.

---

# 72. Closure Delivery

Routine closure delivery is owned by:

```text
Project Owner
```

or explicitly approved normal delivery automation.

Recommended delivery:

```text
focused closure branch
closure-only PR
merge to main
```

Final closure delivery must be traceable.

After merge:

```bash
git switch main
git fetch --prune origin
git pull --ff-only
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
local main == origin/main
ahead/behind = 0/0
working tree clean
```

---

# 73. Post-Closure Evidence Validity

Closure bookkeeping changes:

```text
tasks/STAGE_07_CLOSURE_REVIEW.md
tasks/STAGE_07_TASK_INDEX.md
tasks/README.md
```

do not by themselves invalidate accepted:

- Backend Phase 2;
- Frontend Phase 2;
- Integration;
- Windows runner;
- Android smoke.

Do not rerun these merely because closure documentation was merged.

If closure delivery unexpectedly includes production behavior changes, stop and re-evaluate evidence before claiming closure.

---

# 74. Final Repository State

Populate after closure merge.

| Check | Expected | Actual | Result |
|---|---|---|---|
| `origin/main` SHA | Closure merge | `<sha>` | `Pending` |
| Local `main` | same | `<sha>` | `Pending` |
| Ahead/behind | `0/0` | `<result>` | `Pending` |
| Working tree | Clean | `<result>` | `Pending` |
| Closure file on main | Yes | `<result>` | `Pending` |
| Stage index final | Yes | `<result>` | `Pending` |
| README Stage status final | Closed | `<result>` | `Pending` |
| Production diff in closure PR | None | `<result>` | `Pending` |

Final stage state is not complete until this repository state passes.

---

# 75. Final Stage 7 Closure Record Template

At execution, complete:

```text
STAGE 7 CLOSURE REVIEW

Stage:
Stage 7 — Student Homework and Submission Flow

Planning baseline:
294d17317ed0c7428171fc20223da65e7a2cafd1

Audited accepted product origin/main:
<sha>

Documentation alignment:
S07-DOC-001 = Accepted / Delivered

Backend:
S07-BE-001 = Accepted / Delivered
S07-BE-002 = Accepted / Delivered
S07-BE-003 = Accepted / Delivered
S07-BE-004 = Accepted / Delivered
S07-BE-005 = Accepted / Delivered
S07-BE-006 = Accepted / Delivered
S07-BE-007 = Accepted / Delivered
S07-BE-PHASE-2 = PASS
Backend findings: P1=<n>, P2=<n>, P3=<n>

Frontend:
S07-FE-001 = Accepted / Delivered
S07-FE-002 = Accepted / Delivered
S07-FE-003 = Accepted / Delivered
S07-FE-004 = Accepted / Delivered
S07-FE-005 = Accepted / Delivered
S07-FE-PHASE-2 = PASS
Frontend findings: P1=<n>, P2=<n>, P3=<n>

Integration:
S07-INT-001 assets = Accepted / Delivered
Harness Preflight = PASS
Windows real-stack = PASS
API security = PASS
DB/private-file oracle = PASS
Restart persistence = PASS
Android manual smoke = PASS
Cleanup = PASS

Roadmap acceptance:
PASS

Stage 8 boundary:
PASS

Stage 9/10 scope boundary:
PASS

Closure findings:
P1 = <n>
P2 = <n>
P3 = <n>

Closure verdict:
STAGE CLOSED

Closure delivery:
PR = <#>
Closure merge = <sha>

Final Git:
main = <sha>
origin/main = <sha>
ahead/behind = 0/0
working tree = clean

Next permitted gate:
Stage 8 planning/decomposition only
```

---

# 76. Stage 7 Closure Acceptance Summary

Stage 7 is considered complete only when final accepted evidence proves:

```text
Student can execute assigned Homework
+
up to 3 separate normal Attempts
+
all 9 answer types
+
private file submission
+
protected own-file access
+
explicit Submit
+
deadline/Teacher-close auto-finalization
+
durable Start/Submit idempotency
+
frozen official Homework meaning
+
Tenant/ownership/privacy
+
desktop/mobile real-stack behavior
+
no Stage 9 scoring/checking leakage
```

and the complete accepted result is delivered to `origin/main`.

---

# 77. Next Stage Gate

After:

```text
Closure verdict = STAGE CLOSED
closure bookkeeping merged
local main == origin/main
ahead/behind = 0/0
working tree clean
```

the only next permitted product gate is:

```text
Stage 8 — Blitz Task Workflow
planning/decomposition
```

Do not begin Stage 8 implementation directly from Stage 7 closure.

Stage 8 must start with a fresh ChatGPT read-only recovery of current GitHub `main` and the Project Workflow.

---

# 78. Final Rule

Stage 7 closure is not a ceremonial status update.

It certifies that:

1. the approved Student Homework execution system is implemented;
2. block-level backend/frontend quality gates passed;
3. the real production stack passed integration;
4. security/Tenant/private-file boundaries were independently verified;
5. lifecycle/idempotency/persistence behavior was proven;
6. required mobile smoke passed;
7. integration fixture state was cleaned;
8. later Stage boundaries remain intact;
9. the final accepted state is present on GitHub `main`;
10. no unresolved blocking finding remains.

Only then:

```text
STAGE 7 = CLOSED
```
