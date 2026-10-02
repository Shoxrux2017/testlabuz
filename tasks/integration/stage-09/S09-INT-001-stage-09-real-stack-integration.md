# Integration Contract: S09-INT-001 — Stage 9 Real-Stack Checking and Scoring Integration

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-INT-001` |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | Integration: real-stack Windows E2E, API security, DB oracle, Android manual smoke |
| Status | `Approved` |
| Depends on | `S09-BE-PHASE-2 = PASS` (PR #301); `S09-FE-PHASE-2 = PASS` (PR #311) |
| Implementation baseline | `origin/main` `f0259c8` |
| Production changes allowed | **None**. Integration and test assets only |
| Harness implementation | Claude |
| Integration Harness Preflight | Claude plus an independent fresh-context reviewer, before the first full run (`tasks/README.md` §12.1) |
| Windows real-stack run, API and DB scenarios | Claude (owner decision `S09-INT-D1`) |
| Android manual smoke | Project Owner (`S09-INT-D1`) |
| Delivery | Claude opens the PRs; the Project Owner merges |

**Owner decision `S09-INT-D1` = A (2026-10-02).** This repeats the Stage 8 arrangement (`INT-D1`, `INT-D4`):
- Claude runs the Windows real-stack runner and the direct API/DB scenarios.
- The Project Owner performs the Android manual smoke from the printed checklist.
- While a full run or the Android smoke is in progress, no other Claude session works in this repository. The exclusive-database and audited-checkout checks detect a violation.

This file is the complete task contract. It names the Stage 8 assets whose proven primitives are reused (§6). The implementer reads only those files and the production code that a fixture or assertion depends on.

## 2. Goal

Prove on the real Laravel + PostgreSQL + Flutter Windows stack that Stage 9 works end to end:
- frozen Attempts are checked automatically, both right after a freeze and by the scheduled commands;
- the desktop Teacher reviews and corrects judgment answers;
- official Homework and Blitz scores are selected correctly, including the overtake wait and an exception replacement;
- the Student sees results only as the release mode allows;
- the Teacher downloads a submitted file;
- the Tenant and privacy boundaries hold.

An independent DB oracle judges every state change. The Project Owner confirms the mobile surface on Android.

## 3. Workflow

```text
PR 1 (this branch): contract + integration assets + bookkeeping
  -> focused asset verification (§15)
  -> Integration Harness Preflight (§16), fixes, re-review
  -> PR 1 opened; Project Owner merges
Run on the merged main (audited clean checkout):
  -> Windows real-stack run (§13)
  -> Android manual smoke (§12)
  -> final integration review
PR 2: execution record (and any harness-only fixes)
```

A failed full run is classified first (§5). A harness-only failure is fixed on a new branch and run again. Production behavior is never changed in this task.

## 4. Scope

Included:
- automatic checking through the post-response trigger (Homework Submit, Blitz Submit);
- automatic checking through the scheduled commands `homework:reconcile-deadlines`, `blitz:reconcile-timeouts`, `attempts:check-frozen` and the official-score repair, plus the schedule registration and one `schedule:run`;
- the exact partial-credit arithmetic of all nine Question types, including the 8-decimal storage rounding;
- the Teacher review queue (task-scoped and global), submission detail, partial review, full review, correction, official-score panel and review counts, all on Windows desktop UI;
- setting the Homework review deadline through the date and time pickers;
- the Teacher submitted-file download (UI Save As and API);
- the official Homework score, including the "could overtake" wait;
- the official Blitz score: exception grant through the UI (with the warning), withdrawal, and the replacement becoming official;
- Student results under release mode `automatic` (UI and API) and `manual_teacher` (UI and API), and Blitz results hidden while the Blitz is active;
- the review API error contract (`409 automatic_checking_pending`, `422` vectors);
- the Tenant/role/privacy matrix over every Stage 9 endpoint;
- restart persistence;
- Android: Student results and Teacher read-only counts (manual).

Non-goals:
- any production code change;
- Student answering through the UI (proven by the Stage 7/8 integrations and `FE-UX-001`); Students answer through the API here;
- a real-concurrency race probe. The backend already proves review-save and checking serialization with real PostgreSQL concurrency (`TeacherSubmissionReviewConcurrencyTest`, `OfficialScoreResolverConcurrencyTest`). Its two missing real-concurrency cases (grant against checking, sweep against Submit) are listed in §18 for the closure review;
- Stage 10 (release actions, Topic results, Parent visibility);
- updating the Stage 8 harness. It is historical evidence and is not run against the Stage 9 backend.

## 5. Integration Principle and Failure Classification

This task verifies delivered behavior. Every material failure is first classified as exactly one of:

```text
production defect           -> stop the scenario, keep the evidence, report;
                               the fix gets its own contract
integration-harness defect  -> fix only the integration/test asset
environment/runtime defect  -> fix the environment without changing production
```

Before calling something a production defect, confirm that the harness expectation matches the approved production contract (`S09-DOC-001` and the delivered code). Failure messages start with `production defect:`, `integration-harness defect:` or `environment/runtime defect:`.

## 6. Reused Stage 8 Primitives

Stage 9 reuses the proven Stage 8 primitives as **new `stage9_*` files**. Each one is copied with Stage 9 identities and adapted only where Stage 9 differs.

**Why copies, not shared code.** Every Stage 8 helper binds Stage 8 identities as script constants: container, volume, port, mutex, marker, refusal prefix, manifest namespace and password variable. Making them shared would mean changing and re-verifying closed Stage 8 evidence assets.

| Stage 9 file | Source primitive | What changes |
|---|---|---|
| `frontend/integration_test/stage9_runtime_guard.ps1` | `stage8_runtime_guard.ps1` | Stage 9 identities (§7); the safe-refusal prefix `Stage 9 `; one new check: no other `testlabuz-stage*-e2e-app` container is running |
| `frontend/integration_test/verify_stage9_runtime_guard.ps1` | `verify_stage8_runtime_guard.ps1` | Same matrices, plus the new container check |
| `frontend/integration_test/stage9_test_files.ps1` | `stage8_test_files.ps1` | Only `answer_pdf`; temp root `testlabuz-stage9-fixtures-<guid32>` |
| `frontend/integration_test/verify_stage9_test_files.ps1` | `verify_stage8_test_files.ps1` | Same checks for the one fixture |
| `frontend/integration_test/stage9_api_security.ps1` | `stage8_api_security.ps1` (envelope, success, recursive key denylist, download, public-path, redaction, transport, sessions, negative-probe snapshots) | Stage 9 path allowlist, denylist (§11.4), matrices (§9.6) |
| `frontend/integration_test/verify_stage9_api_security.ps1` | `verify_stage8_api_security.ps1` | Stage 9 synthetic cases |
| `frontend/integration_test/stage9_oracle.ps1` | `stage8_oracle.ps1` (facts shell, sentinels, cleanup facts, disk identity, audited checkout, runner plan, guarded command, waits, comparison helpers) | Stage 9 facts and assertions (§10); the guarded-command pattern for the three scheduled commands, `schedule:list` and `schedule:run` |
| `frontend/integration_test/verify_stage9_oracle.ps1` | `verify_stage8_oracle.ps1` | Stage 9 synthetic cases |
| `frontend/integration_test/stage9_api_scenarios.ps1` | `stage8_api_scenarios.ps1` (evidence recording) | All Stage 9 scenarios (§9) |
| `frontend/integration_test/run_stage9_windows_e2e.ps1` | `run_stage8_windows_e2e.ps1` | Stage 9 plan (§13); the runtime manifest for the UI (§9.4) |
| `frontend/integration_test/prepare_stage9_manual_smoke.ps1` | `prepare_stage8_manual_smoke.ps1` | Stage 9 Android setup and checklist (§12) |
| `frontend/integration_test/stage9_e2e_support.dart` | `stage8_e2e_support.dart` (harness, waits, key generator, loaders, checkpoint protocol, file sink) | Stage 9 env, logins, runtime manifest, a Teacher file sink; no picker override |
| `frontend/integration_test/stage9_review_flow_test.dart` | — | New flow (§9.4) |
| `backend/database/seeders/Stage9E2eSeeder.php` | `Stage8E2eSeeder.php` (guard, private disk, submission key check, manifest, `fixtureRows`, `ownedState`, cleanup, sentinels) | Stage 9 fixtures (§8); ownership of Stage 9 rows |
| `backend/tests/Feature/Seeders/Stage9E2eSeederTest.php` | `Stage8E2eSeederTest.php` | Stage 9 cases (§8.7) |

`stage5_e2e_support.dart` (`stage5Sha256`) is imported, as Stage 8 does. Stage 8 files are not modified.

The lessons proven in Stage 8 are kept:
- Statically check an existing container's configuration before `docker start`.
- Require an audited clean checkout of `backend/ frontend/ docker/` and an unchanged HEAD, both at start and right before the PASS line.
- Secrets travel over stdin only, never in a container file or argv.
- Bound every external command:
  - container PHP 300 s;
  - seeder test 900 s;
  - scheduled commands `timeout --kill-after=10 300`, with 124 and 137 classified as timeouts.
- Use `testlabuz_testing` exclusively. Check this after the guard, before every scheduled command, and before PASS.
- The runner and the smoke preparation exclude each other through the mutex and the marker. The marker is removed before any `adb` step, and `-AbandonManualSmoke` exists.
- Safe refusals pass through as `{"stage9_refusal": …}` with exit 3. They are redacted with every input string value.
- Claim "state preserved" only after state was touched.
- Use `--no-reload` with `PHP_CLI_SERVER_WORKERS=4`.
- Always send `Accept: application/json`.
- Item ids that Students can see are permuted, so their sort order reveals no key.
- Use bounded condition waits, never sleeps. Keep the Windows test window visible: Flutter stops frames for a hidden window (`INT-D7`).

## 7. Runtime

| Item | Value |
|---|---|
| Backend container | `testlabuz-stage9-e2e-app`, image `testlabuz-app:latest`, command `php artisan serve --host=0.0.0.0 --port=8000 --no-reload`, `PHP_CLI_SERVER_WORKERS=4` |
| Port | `127.0.0.1:18009:8000`; API target `http://127.0.0.1:18009/api/v1` (exact regex) |
| Private volume | `testlabuz-stage9-e2e-private-files` at `/var/www/html/storage/app/private` |
| Backend bind | `<repo>/backend` → `/var/www/html` (read/write) |
| Database | `testlabuz-postgres-1` (`postgres:18.4`), network `testlabuz_default`, database `testlabuz_testing`, user `testlabuz`; `DB_PASSWORD` from `docker/.env` `POSTGRES_PASSWORD`, by name only |
| Environment | `APP_ENV=testing`, `APP_DEBUG=false`, `CACHE_STORE=file`, `SESSION_DRIVER=file`, `QUEUE_CONNECTION=sync` |
| Mutex / marker | `Local\TestLabUzStage9Harness`; `%TEMP%\testlabuz-stage9-manual-smoke.pending` |
| Password | `STAGE9_E2E_PASSWORD` (Process or User environment, at least 16 characters, never printed) |
| Flutter | `frontend/.fvm/flutter_sdk/bin/flutter.bat`, version equal to `frontend/.fvmrc` |

The live guard is the Stage 8 guard with Stage 9 identities. It is fail-closed, and each of these checks throws on failure:
- container facts, mounts, ports and named environment;
- PostgreSQL identity;
- `/proc` facts: one `artisan serve`, one `php -S` master with exactly 4 workers, and **no `schedule:run` or `schedule:work` resident**;
- the in-container Laravel facts, including zero pending migrations and the private disk;
- session correlation;
- the unauthenticated `GET /auth/me` probe (401 exact envelope).

New check: no other `testlabuz-stage*-e2e-app` container is running. Such containers share `testlabuz_testing`.

Pending migrations fail the guard as an environment defect. The operator runs `php artisan migrate` in the container and starts again.

## 8. Fixtures — `Stage9E2eSeeder`

### 8.1 Namespace and guards

- Identifiers:
  - `id(n)` = `09000000-0000-4000-8000-%012d`; sentinel ids `09999999-0000-4000-8000-%012d`;
  - logins `e2e_s09_<name>`; full names `E2E S09 <Words>`; titles `E2E S09 …`.
- Every `RuntimeException` message starts with `Stage 9 `.
- Guards, as in Stage 8:
  - `testing` environment, `pgsql`, `current_database() = testlabuz_testing`;
  - a non-blank `STAGE9_E2E_PASSWORD`, which the read-only `ownedState` and `sentinelState` do not need;
  - a private local non-public disk under `storage/app/private`;
  - exact submission blob keys `student-submissions/<inst>/<attempt>/<question>/<uuidv4>.(pdf|docx|ppt|pptx)`.
- Operations: `run`, `cleanupOwnedState`, `ownedState`, `ensureSentinels`, `sentinelState`, `removeSentinels`, `manifest`.
- Relative times. Fixtures that must be due or still running when the run reaches them are relative to the seed time (`now()`):
  - deadlines;
  - activation of active Blitz;
  - in-progress Attempts.

  History uses fixed timestamps in 2020. Seeded times are whole seconds.

### 8.2 Institutions, users, groups, Topics

| Institution | `student_result_release_mode` | `blitz_timer_start_mode` | Timezone |
|---|---|---|---|
| `auto` | `automatic` | `synchronized` | `Asia/Tashkent` |
| `manual` | `manual_teacher` | `synchronized` | `Asia/Tashkent` |

Settings rows also carry `learning_material_max_mb = 25` and `student_submission_max_mb = 15`.

| User | Institution | Role | Use |
|---|---|---|---|
| `teacher` | auto | teacher | Owns every auto Topic; member of every auto Group; the UI Teacher |
| `peer_teacher` | auto | teacher | Active member of the `review` Group; owns no Topic (same-Institution non-owner probes) |
| `student` | auto | student | UI Student: reviewed Homework, exception Blitz |
| `classmate` | auto | student | Overtake scenario; classmate privacy probes |
| `backfill_student`, `repair_student`, `deadline_student`, `timeout_student` | auto | student | Scheduled-command fixtures |
| `android_student`, `android_classmate` | auto | student | Android smoke |
| `manual_teacher` | manual | teacher | Owns the manual Topic; foreign-Tenant probes |
| `manual_student` | manual | student | Hidden-results Student |

Every user is active, with `must_change_password = false`. Passwords are hashes of `STAGE9_E2E_PASSWORD`.

Each Topic has its own Group. Every Topic and Group is active.

| Topic = Group | Institution | Group students | Group Teachers | Result pair (Homework, Blitz) |
|---|---|---|---|---|
| `review` | auto | `student`, `classmate` | `teacher`, `peer_teacher` | (`review_hw`, `exception_blitz`) |
| `backfill` | auto | `backfill_student`, `repair_student`, `deadline_student`, `timeout_student` | `teacher` | (`repair_hw`, `backfill_blitz`) |
| `android` | auto | `android_student`, `android_classmate` | `teacher` | (`android_hw`, `android_blitz`) |
| `manual` | manual | `manual_student` | `manual_teacher` | (`manual_hw`, none) |

Pairs, cohort snapshots and locks are seeded as production would leave them once these Attempts exist. The seeder test proves it (§8.7).

### 8.3 Assessments and Questions

Official pair tasks use assignment mode `group`: their recipients are all students of the Topic's Group (`assignment_source = group`), so both tasks of a pair have the same established cohort, as production requires. Practice tasks use `selected_students` with the listed recipients (`direct`). Points are Question points. `total_possible_points` is their sum.

| Assessment | Type, state | Recipients | Questions (position: type points — key) |
|---|---|---|---|
| `review_hw` | Homework, active, deadline seed + 30 days, `review_due_at` `2026-01-15T13:00:00Z` (18:00 Tashkent, past) | student, classmate (group) | 1: single_choice 2 — option 2 of 4; 2: multiple_choice 3 — options 1, 3, 5 of 5; 3: short_written **manual** 5; 4: open_written 5; 5: file_based 5 |
| `exception_blitz` | Blitz, active, synchronized, duration 3600, activated at seed time, ends seed + 3600 s | student, classmate (group) | 1: single_choice 4 — option 1 of 3; 2: open_written 6 |
| `manual_hw` | Homework, active, deadline seed + 30 days | manual_student (group) | 1: single_choice 5 — option 3 of 3; 2: open_written 5 |
| `backfill_hw` | Homework, closed (practice) | backfill_student | 1: single_choice 2 — option 1 of 3; 2: multiple_choice 3 — options 2, 3, 4 of 5; 3: true_false 1 — `false`; 4: short_written automatic 2 — accepted `Oʻzbekiston` (U+02BB); 5: fill_in_blank 3 — blank 1 `Tashkent`, blank 2 `Samarkand`; 6: matching 3 — three left items; 7: ordering 4 — three items; 8: open_written 5; 9: file_based 5 |
| `backfill_blitz` | Blitz, closed, snapshot `individual`, duration 600 (pair) | the four `backfill` students (group) | 1: multiple_choice 1 — 3 correct of 4; 2: ordering 1 — three items; 3: true_false 1 — `true` |
| `repair_hw` | Homework, closed (pair) | the four `backfill` students (group) | 1: single_choice 4 |
| `deadline_hw` | Homework, active, deadline seed − 10 min (practice) | deadline_student | 1: single_choice 3; 2: true_false 1 — `false` |
| `timeout_blitz` | Blitz, active, snapshot `individual`, duration 600, activated seed − 1 h (practice) | timeout_student | 1: true_false 2 — `true`; 2: single_choice 2 |
| `android_hw` | Homework, active, deadline seed + 30 days, `review_due_at` `2026-01-15T13:00:00Z` | android_student, android_classmate (group) | 1: single_choice 2; 2: open_written 3 |
| `android_blitz` | Blitz, active, synchronized, duration 3600, activated at seed time | android_student, android_classmate (group) | 1: single_choice 2; 2: open_written 2 |

Every Question set passes the production `AssessmentActivationValidator`. Nested item ids that Students can see (options, matching and ordering items, blanks) are permuted, as in Stage 8.

### 8.4 Seeded Attempts (pre-Stage-9 history shapes)

| Attempt | State | Saved answers (all `pending`, no checking metadata) |
|---|---|---|
| `backfill_hw` #1 (backfill_student) | `submitted`, `student_submit`, history times, `possible_points` 28 | Q1 correct; Q2 options 2, 1, 5 (1 correct); Q3 `false`; Q4 `"  o'ZBEKISTON "`; Q5 `TASHKENT`, `Bukhara`; Q6 one of three pairs correct (a full matching cannot have exactly two); Q7 exactly one item at its correct position; Q8 text; Q9 no answer |
| `backfill_blitz` #1 (backfill_student) | `timed_out_finalized`, `timeout_auto_submit`, history times, `possible_points` 3 | Q1 one correct option; Q2 exactly one item at its correct position; Q3 `true` |
| `repair_hw` #1 (repair_student) | `checked`, `student_submit`; answer Q1 `auto_checked` `4.00000000`; earned 4, possible 4, normalized `100.00000000`, scoring and checking times in history | **No official row** (the repair case) |
| `deadline_hw` #1 (deadline_student) | `in_progress`, started seed − 30 min, `deadline_at` = the Homework deadline | Q1 correct |
| `timeout_blitz` #1 (timeout_student) | `in_progress`, started seed − 20 min, `deadline_at` started + 600 s (past) | Q1 `true` |

### 8.5 Sentinels

An unrelated graph in a sentinel Institution, built as in Stage 8: Institution, settings (release `null`), users, Group, Topic, a practice Homework, an Attempt, answers, a File and its private blob.

The sentinel Attempt is `checked`, with consistent scores and an `auto_checked` answer. It is **never a candidate** of any scheduled command or of the repair. Cleanup, the scheduled commands and the whole run must leave it byte-identical.

### 8.6 Ownership and cleanup

`ownedState` is the Stage 8 fail-closed ownership walk, extended to Stage 9 rows.

**Static rows** match their identity columns (ids, `*_id` columns, logins, names, titles, roles, types, assignment fields). The columns that the run changes (`homework_assignments.review_due_at`, the `blitz_tasks` status and close time, `topic_result_pairs.locked_at`) are not identity columns. No static `*_id` column changes in a Stage 9 run.

Seeded Attempts, their answers and typed answer rows are owned through the dynamic walk, like the rows a run creates.

**Dynamic rows** are owned only through owned parents:
- Attempts of owned Assessments by owned Students;
- answers and typed answer children;
- `attempt_answers` checking columns;
- `official_task_scores` of owned Assessments and Students, pointing to owned Attempts;
- `blitz_attempt_exceptions`;
- Files linked through `answer_files`, or proven by their exact key;
- blobs enumerated at exact keys;
- `idempotency_records` of manifest users with owned result resources;
- `personal_access_tokens` of manifest users.

Any unowned row attached to an owned parent makes `ownedState` and cleanup refuse.

**Cleanup** is one transaction in FK-safe order, with `official_task_scores` deleted before Attempts. Exact blob deletes and empty-directory removal follow. The result is `{cleaned: true, operation, disk: "local", root: "/var/www/html/storage/app/private"}`.

### 8.7 `Stage9E2eSeederTest` (inside the Stage 9 container)

The test uses `DatabaseTransactions`, a fixed `travelTo`, a test password and an isolated test disk.

1. Unsafe guards (wrong environment, driver or database, blank password, unsafe disk) × every operation: nothing is written.
2. Reseed converges: `run` twice gives the identical owned state, and `manifest()` is stable.
3. Every Question set passes `AssessmentActivationValidator`, and visible nested ids are permuted.
4. The scheduled commands see exactly the expected candidates right after seeding:
   - `homework:reconcile-deadlines` = {`deadline_hw`} (after the deadline);
   - `blitz:reconcile-timeouts` = {`timeout_blitz`};
   - `attempts:check-frozen` = {`backfill_hw` #1, `backfill_blitz` #1};
   - repair = {`repair_student` on `repair_hw`}.
5. Running the three commands in the test produces exactly the §9.3 table (every awarded point, status, score and official row), and a second run changes nothing. This pins the fixture arithmetic before any live run.
6. Cleanup removes dynamic rows created by real production Actions, then reseed converges to the baseline. The Actions are:
   - Homework Start, typed save, file save, Submit and the post-freeze checking drain;
   - review save (`ReviewTeacherSubmission`) with official rows;
   - Blitz Submit, exception grant and replacement Start.

   Cleanup runs twice. Sentinels stay untouched.
7. Fail-closed cases: an unowned `official_task_scores` row for an owned Attempt, an unowned Attempt on an owned Assessment, and an unowned File under an owned Attempt directory. Each makes `ownedState` and cleanup refuse.
8. Sentinel idempotency and tamper detection. The sentinel is not a candidate of any scheduled command.
9. Read-only inspection works without a password.

## 9. Scenarios and Exact Expected Results

All scores below are the stored `normalized_score`, with 8 decimals. The UI shows them with one decimal, half-up (`S09-T3`). "Poll" means a bounded condition wait of at most 30 s: checking runs after the response is sent.

### 9.1 API setup and trigger checking (before the UI)

**`freeze_trigger_checking`** — `review_hw`, `student` #1:
- Steps:
  1. Start (Idempotency-Key).
  2. Save: Q1 option 2; Q2 options 1, 3, 4; Q3 `Photosynthesis needs light.`; Q4 `Open written answer for review.`; Q5 upload `answer_pdf`.
  3. Submit. The Submit response shows status `submitted` (the Stage 7 response is unchanged).
- Poll the Student Attempt read until `waiting_for_teacher_review`.
- Oracle:
  - Q1 `auto_checked` `2.00000000`; Q2 `auto_checked` `2.00000000`;
  - Q3–Q5 `waiting_for_teacher_review` with null points;
  - automatic `checked_at` set and `checked_by_user_id` null;
  - `attempt_answers.updated_at` unchanged by checking;
  - Attempt earned and normalized null;
  - no official row for `student`.

**`homework_overtake`** — `review_hw`, `classmate`:
1. #1: Q1 option 2, Q2 options 1, 3, 5, Submit. Poll until `checked`.
   - Oracle: earned 5, normalized `25.00000000`; official row `highest_valid_completed`, #1, `25.00000000`.
   - Teacher official read `ready` 25. Student Homework read `official_score` `{normalized_score: 25, attempt_number: 1}`.
2. #2: Q1 option 2, Q2 options 1, 3, 5, Q4 `Second attempt answer.`, Submit. Poll until `waiting_for_teacher_review`.
   - Upper bound (2 + 3 + 5) / 20 = 50 > 25, so: no official row.
   - Teacher read `waiting_for_teacher_review`. Student read `official_score: null`.
3. Teacher API review of #2: Q4 `awarded_points 1`, `feedback null`.
   - #2 `checked`, earned 6, normalized `30.00000000`.
   - Official row #2, `30.00000000`, `highest_valid_completed`.
   - Student read `{30, 2}`, and `attempt_results` #1 25 and #2 30.

**`blitz_review_official`** — `exception_blitz`, `student` #1:
1. Start, Q1 option 1, Q2 `Blitz answer one.`, Submit. Poll until `waiting_for_teacher_review`.
2. Teacher API review: Q2 `3`, feedback `Blitz feedback one.`
   - #1 `checked`, earned 7, normalized `70.00000000`.
   - Official row `valid_normal_blitz`, `70.00000000`.
3. Hidden while active (`S09-D5`):
   - `/student/blitz/active` and `/student/blitz/{id}` contain no `result`, score or feedback key;
   - `/student/blitz/finished` does not list the Blitz.

**`manual_release_hidden`** — `manual_hw`, `manual_student` #1:
1. Q1 option 3, Q2 `Manual institution answer.`, Submit. Poll until waiting.
2. `manual_teacher` reviews Q2 `4`, feedback `Hidden feedback.`
   - `checked`, earned 9, normalized `90.00000000`; official row `90.00000000`.
   - Teacher official read `ready` 90.
3. The Student reads are hidden:
   - Homework list item and detail: `score_visible: false`, `official_score: null`;
   - `attempt_results[0].result` = `{visible: false, normalized_score: null}`;
   - Attempt read: `result` hidden and every answer `feedback: null`.

### 9.2 Review error contract (before the scheduled commands)

**`review_transport`.** Every probe is a negative probe (§11.3): tables and blobs unchanged, exact envelope.

| Probe | Expected |
|---|---|
| `PUT /teacher/submissions/{backfill_hw #1}/review` with a valid shape (still `submitted`) | `409 automatic_checking_pending` |
| `awarded_points` greater than the Question points (Q3 of `student` #1: 5.5) | `422`, `answers.0.awarded_points` |
| `awarded_points` `-1`; `awarded_points` `1.1234567` | `422`, `answers.0.awarded_points` |
| `feedback` of 2001 characters | `422`, `answers.0.feedback` |
| `answer_id` of an `auto_checked` answer (Q1) | `422`, `answers.0.answer_id` |
| Duplicate `answer_id` (different case) | `422`, `answers.1.answer_id` |
| Missing `feedback` key; an extra item key; an extra top-level key; a query parameter; a non-JSON body | `422` with the documented field |
| `GET /teacher/submissions?unknown=1`; `GET /teacher/submissions/{id}?x=1` | `422` |

### 9.3 Scheduled checking — `scheduled_checking`

1. `php artisan schedule:list` lists `homework:reconcile-deadlines`, `blitz:reconcile-timeouts` and `attempts:check-frozen`, each at `* * * * *`.
2. Before each command: a safety check over facts that are a strict superset of the production candidate predicate. Every candidate must be manifest-owned, and the sentinels are captured. Afterwards: the sentinels are unchanged and the exclusive-database check passes.
3. Guarded invocations, each with exact output and exit code 0:

| Command | Exact output |
|---|---|
| `homework:reconcile-deadlines` | `Candidates: 1; finalized attempts: 1; failures: 0.` |
| `blitz:reconcile-timeouts` | `Candidates: 1; finalized attempts: 1; failures: 0.` |
| `attempts:check-frozen` | `Candidates: 2; checked attempts: 2; failures: 0.` then `Official scores repaired: 1; failures: 0.` |
| `attempts:check-frozen` (again) | `Candidates: 0; checked attempts: 0; failures: 0.` then `Official scores repaired: 0; failures: 0.` |

4. One guarded `php artisan schedule:run`: exit 0, every one of the three commands reported as run and none as failed. The oracle then sees no table change.

Expected state (oracle):

| Attempt | Answers (`awarded_points`) | Attempt result | Official row |
|---|---|---|---|
| `backfill_hw` #1 | Q1 `2.00000000`, Q2 `1.00000000`, Q3 `1.00000000`, Q4 `2.00000000`, Q5 `1.50000000`, Q6 `1.00000000`, Q7 `1.33333333` (all `auto_checked`); Q8 `waiting_for_teacher_review`; Q9 no row | `waiting_for_teacher_review`; earned/normalized null | none (practice) |
| `backfill_blitz` #1 | Q1 `0.33333333`, Q2 `0.33333333`, Q3 `1.00000000` | `checked`; earned `1.66666666`; normalized `55.55555533` (sum of stored values, not 5/9) | `valid_normal_blitz`, `55.55555533` |
| `repair_hw` #1 | unchanged | unchanged | **created** by the repair: `highest_valid_completed`, `100.00000000` |
| `deadline_hw` #1 | Q1 `3.00000000` | `homework_deadline_auto_submit`, `finalized_at` = deadline, then `checked`; earned 3, normalized `75.00000000` | none |
| `timeout_blitz` #1 | Q1 `2.00000000` | `timeout_auto_submit`, then `checked`; earned 2, normalized `50.00000000` | none |

For every row:
- `finalization_reason`, `submitted_at`, `finalized_at` and `locked_at` match the freeze;
- `attempt_answers.updated_at` is unchanged by checking;
- automatic answers have `checked_by_user_id` null and `checked_at` set.

### 9.4 Windows UI flow — `stage9_review_flow_test.dart`

**Launch.** One `testWidgets`, launched by the runner exactly like Stage 8:

```text
flutter test integration_test/stage9_review_flow_test.dart -d windows --no-pub --dart-define=API_BASE_URL=<target>
```

- View: 1600×1000 at DPR 1.
- Provider overrides: `appConfigProvider`, `idempotencyKeyGeneratorProvider` (`Stage9Keys`; the UI issues exactly 1 key, for the grant) and `localFileActionsProvider` (`Stage9FileSink`).
- The sink checks the save:
  - dialog title `Save submitted file`;
  - file name = the fixture's original name;
  - bytes SHA-256 = the fixture SHA-256.

  It returns a non-null Uri.
- The runner passes a runtime manifest JSON with the static ids plus the ids created in §9.1: `student` #1 Attempt, its answer ids (Q3, Q4, Q5) and its File id; `exception_blitz` #1.
- Checkpoints use the Stage 8 file protocol (`checkpoint-<name>.json` → DB oracle → `.ack.json`, 3-minute wait).
- Navigation rule: Stage 9 navigation is exercised through its controls, namely the `Review queue` button, `Open review queue` and queue rows. A deep link (`go`) may only reach a screen from an earlier stage.

**Teacher (`e2e_s09_teacher`)**

1. Sign in through the login UI and reach `teacherLearningWorkspace`.
2. On the `review_hw` detail:
   - `teacherTaskReviewWaitingCount` = `Waiting for review: 1`; `teacherTaskReviewOverdueCount` = `Overdue: 1`.
   - Set the deadline: `teacherHomeworkReviewDeadlineSetButton`, then the date picker in input mode (date = run date + 7 days), then OK on the time picker. The initial time is the current deadline's 18:00. Wait for `Review deadline saved.`, then `Overdue: 0`.
   - **Checkpoint `review_deadline_set`** (the payload carries the typed date). Oracle: `review_due_at` = typed date 18:00 Asia/Tashkent in UTC (13:00Z); nothing else changed.
3. `teacherTaskReviewQueueButton` → the scope label reads `Submissions of this Homework`. Exactly one row, `teacherReviewQueueRow:<student #1>`, containing `Waiting for review` and `Reviewed 0 of 3 answers`. Tap it.
4. The detail opens at `/teacher/reviews/<id>`:
   - Q1 block contains `Checked automatically · 2 of 2 points`; Q2 contains `Checked automatically · 2 of 3 points`.
   - Q3–Q5 show `Waiting for review` and review fields.
   - The official panel shows `Waiting for Teacher review.`
5. `teacherSubmissionFileSaveButton:<fileId>` → `File saved.`; the sink recorded 1 save.
6. Partial review: Q3 points `4.5`, feedback `Clear reasoning.` → `1 answer changed` → `Save review` → `Review saved.`
   - Q3 shows `Reviewed by E2E S09 Teacher · 4.5 of 5 points`; the panel still shows `Waiting for Teacher review.`
   - **Checkpoint `review_partial`.** Oracle:
     - Q3 `teacher_checked` `4.50000000`, the feedback, `checked_by_user_id` = teacher;
     - Q4/Q5 waiting; the Attempt waiting with null score;
     - no official row for `student`; classmate rows unchanged.
7. Q4 `3.25` with feedback `Good structure, add an example.`; Q5 `5` without feedback → `2 answers changed` → Save → `Review saved.`
   - The panel shows `Score 83.8` and `Attempt 1 · Best checked attempt · This submission`.
   - **Checkpoint `review_saved`.** Oracle:
     - Attempt `checked`, earned `16.75000000`, normalized `83.75000000`, `scoring_completed_at` set;
     - Q5 feedback null;
     - official row `highest_valid_completed` #1 `83.75000000`.
8. Correction: Q4 `1.27` → Save → `Review saved.` The panel shows `Score 73.9`.

   73.85 as a binary double is slightly below the half, so plain `toStringAsFixed(1)` would show `73.8`.
   - **Checkpoint `review_corrected`.** Oracle:
     - Q4 `1.27000000`, feedback unchanged;
     - earned `14.77000000`, normalized `73.85000000`, still `checked`, `scoring_completed_at` advanced;
     - the same official row id with `73.85000000` and an advanced `selected_at`.
9. Exception grant, on the `exception_blitz` detail:
   - `teacherTaskReviewWaitingCount` = `Waiting for review: 0`.
   - `teacherBlitzMonitorButton` → `teacherBlitzGrantButton:<student>`.
   - The dialog's `teacherBlitzAttemptExceptionOfficialScoreWarning` text equals the delivered warning exactly.
   - Choose a reason type, enter reason `Power outage during the Blitz.`, tap `teacherBlitzAttemptExceptionSubmit`, wait for `Additional Blitz attempt granted.`
   - **Checkpoint `exception_granted`.**
     - Oracle: the exception row; #1 `official_score_eligible = false`; no official row for `student` on `exception_blitz`; one completed grant idempotency record with the UI key. The Teacher official read is `waiting_for_replacement`.
     - The runner then:
       1. Starts replacement #2 as `student` (`start_replacement`), saves Q1 option 1 and Q2 `Replacement answer.`, and submits. It polls until waiting.
       2. Reviews Q2 as the Teacher: `5.5`, feedback `Replacement feedback.`
       3. Has the oracle confirm #2 `checked`, normalized `95.00000000`, and an official row `approved_blitz_exception_replacement` `95.00000000`. Then it acks.
10. `teacherLearningWorkspace` → `teacherReviewQueueButton` → global queue. Set Status `Checked` and Task `Blitz`.
    - The row `teacherReviewQueueRow:<exception #1>` contains `Invalidated attempt`. Tap it.
    - The panel shows `Score 95.0` and `Attempt 2 · Replacement attempt`.
    - **Checkpoint `replacement_seen`.** The runner closes `exception_blitz` through the Teacher API. The oracle confirms the Blitz `closed` and the official row unchanged. Then it acks.
11. Sign out.

**Student (`e2e_s09_student`, release `automatic`)**

12. Workspace → `studentFinishedBlitzCard<exception_blitz>`:
    - `studentFinishedBlitzResult<id>` = `Score 95.0`;
    - the card contains `Attempt 1 was invalidated.`;
    - `studentFinishedBlitzFeedback<id>` contains `Question 2: Replacement feedback.`
13. `review` Topic detail → `studentHomeworkOfficialScore<review_hw>` = `Official score: 73.9`.
14. Homework detail:
    - `studentHomeworkOfficialScore` = `Official score: 73.9 (Attempt 1)`;
    - `studentHomeworkAttemptResult<#1>` = `Attempt 1 · Checked · Score 73.9`.
15. `studentHomeworkOpenAttempt<#1>` → the Attempt screen:
    - `studentAttemptFeedback<Q3>` contains `Clear reasoning.`; `studentAttemptFeedback<Q4>` contains `Good structure, add an example.`;
    - no feedback block for Q1, Q2 or Q5;
    - `studentHomeworkAttemptResult` = `Score 73.9`;
    - the screen contains none of `Correct answer`, `Accepted answers`, `Checked automatically`, `Reviewed by`.
16. Sign out.

**Student (`e2e_s09_manual_student`, release `manual_teacher`)**

17. `manual_hw` detail:
    - `studentHomeworkAttemptResult<#1>` = `Attempt 1 · Checked · Result not available yet`;
    - no `studentHomeworkOfficialScore`.

    On the Attempt screen: no `studentAttemptFeedback*` widget, and `studentHomeworkAttemptResult` = `Not available yet`. Sign out.

**Evidence.** The test writes `ui-evidence.json` with:
- `version` and the checkpoints passed;
- the typed date;
- `grant_key`;
- the sink saves (1) and the saved file's SHA-256;
- the texts observed at steps 7, 8, 10 and 12–15.

### 9.5 Post-UI API scenarios

**`teacher_file_download`** — `GET /files/{student #1 file}/download`:

| Caller | Expected |
|---|---|
| Teacher | `200`; `Content-Type: application/pdf`; `Content-Disposition` attachment with the original name; `X-Content-Type-Options: nosniff`; `Cache-Control` containing `private` and `no-store`; body SHA-256 = fixture |
| `student` (owner) | `200`, same bytes |
| `classmate`, `peer_teacher`, `manual_teacher` | `404 resource_not_found` (negative probes) |

The public paths `/storage/<key>`, `/<key>` and `/storage/app/private/<key>` never return the file.

**`student_results_api`** — exact Student reads after the UI flow:

| Caller | Expected |
|---|---|
| `student`, `review_hw` | `score_visible: true`, `official_score` `{73.85, 1}`, `attempt_results` `[{#1, 1, checked, {visible: true, 73.85}}]` |
| `student`, Attempt read | `result` `{true, 73.85}`; feedback on Q3 and Q4 as saved; null on Q1, Q2, Q5 |
| `student`, `/student/blitz/finished` | the `exception_blitz` item: `attempt_exception: true`, `result` `{attempt_number: 2, visible: true, normalized_score: 95, feedback: [{question_id: Q2, position: 2, text: "Replacement feedback."}]}` |
| `classmate`, `review_hw` | `official_score` `{30, 2}`; two results (25, 30) |
| `manual_student` | as in §9.1, still hidden |

**`tenant_privacy`** — negative probes over every Stage 9 endpoint:
- queue, detail, review `PUT`, official-score read, review-due-at `PUT`, file download.
- Targets: `student` #1 (auto), `exception_blitz` #1 and `manual_student` #1 (manual).

| Caller | Expected |
|---|---|
| Unauthenticated | `401 authentication_required` |
| `student` on Teacher endpoints | `403 forbidden` |
| `peer_teacher` (same Institution, Group member, not Topic owner) | Detail, review, official score, review-due-at, file: `404 resource_not_found`. Queue: `200` with no item |
| `manual_teacher` on auto targets | `404`. Its queue lists only `manual_hw` submissions |
| `teacher` on manual targets | `404`. Its queue lists no manual submission |
| `classmate` | `student`'s Attempt read and file: `404` |

Every Student JSON collected in the run passes the recursive key denylist (§11.4).

### 9.6 Restart persistence — `restart_persistence`

1. Capture: the owned tables and blobs, plus these reads:
   - the Teacher detail of `student` #1;
   - the Teacher official reads (`student` on `review_hw` and `exception_blitz`, `classmate`, `repair_student`);
   - the Student reads of §9.5.
2. Run `docker restart`, wait for the HTTP boundary, run the live guard again.
3. Tables and blobs are identical, and every captured read returns identical JSON.

### 9.7 Cleanup

Final manifest cleanup, then the cleanup oracle re-reads every id and blob of this run, then `removeSentinels`, then the local temp roots are removed. As in Stage 8.

## 10. DB Oracle

`stage9_oracle.ps1` reads facts only through the container PHP transport and the seeder's `ownedState()`, so the oracle can never widen scope. The facts are:
- every owned row (passwords removed), including `official_task_scores`, the checking columns, `review_due_at` and `blitz_attempt_exceptions`;
- blobs (key, size, checksum, public existence);
- sentinels and `observed_at`.

Required assertion families, each with a classified failure prefix:
- the baseline after seeding (§8);
- each §9 expectation, compared exactly as decimal strings with 8 places;
- `updated_at` immutability of answers under checking and review;
- the finalization fields unchanged by checking;
- official rows: identity, policy, score, `selected_at` changes exactly when the Attempt or score changes, and `selected_by_user_id` null;
- negative-probe snapshots (tables and blobs unchanged, no idempotency record for rejected keys);
- the scheduled-command safety facts and sentinels;
- Tenant rows (every dynamic row's `institution_id` matches its owner);
- post-restart identity;
- cleanup and disk identity;
- audited checkout and runner plan.

## 11. API Boundaries

### 11.1 Endpoints exercised

**Teacher**
- `GET /teacher/submissions`
- `GET /teacher/submissions/{id}`
- `PUT /teacher/submissions/{id}/review`
- `GET /teacher/assessments/{a}/students/{s}/official-score`
- `PUT /teacher/homework/{id}/review-due-at` (UI)
- `GET /teacher/homework/{id}`, `GET /teacher/blitz/{id}` (`review_summary`)
- `POST /teacher/blitz/{id}/students/{s}/attempt-exception` (UI)
- `POST /teacher/blitz/{id}/close`

**Student**
- `POST /student/homework/{id}/attempts`
- `PUT /student/attempts/{a}/answers/{q}` (typed and file)
- `POST /student/attempts/{a}/submit`
- `GET /student/attempts/{a}`
- `GET /student/homework`, `GET /student/homework/{id}`
- `POST /student/blitz/{id}/attempts` (intents `start_normal`, `start_replacement`; Idempotency-Key)
- `GET /student/blitz/active`, `GET /student/blitz/{id}`, `GET /student/blitz/finished`

**Shared:** `GET /files/{id}/download`, `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`.

### 11.2 Envelopes

- Errors are exactly `{message, code, errors}`. `errors` is `{}` except for `422 validation_failed`, whose fields are non-empty string arrays.
- Success: `{data}`, with `message` beside `data` on mutations. The review save message is `Submission review saved successfully.`
- Collections carry `meta.pagination` `{page, per_page, total, last_page}`.

### 11.3 Negative-probe discipline

As in Stage 8:
1. Open sessions first, then snapshot.
2. Run the probe.
3. Require that tables and blobs are unchanged and that no idempotency record exists for a rejected key.
4. Require that the error leaks no protected identity, meaning no foreign id or name.

### 11.4 Student protected-key denylist (recursive)

`awarded_points`, `checking_status`, `checked_by`, `checked_by_user_id`, `checked_at`, `is_correct`, `correct_value`, `accepted_answers`, `match_key`, `correct_position`, `earned_points`, `official_attempt_id`, `selection_policy_code`, `selected_at`, `review_due_at`, `review_overdue`.

The implementation confirms against the delivered Student resources that none of these keys is legitimate there. A key that is legitimate is a contract conflict and must be reported, not silently dropped.

## 12. Android Manual Smoke — `prepare_stage9_manual_smoke.ps1`

**Parameters:** `-ApiPort` (required), `-CompleteManualSmokeAndCleanup`, `-AbandonManualSmoke`, `-AndroidDevice <serial>` (required for Complete). The switches are exclusive. Every mode takes the mutex and runs the live guard and the exclusive-database check.

**Prepare**
1. Refuse if the marker exists, naming the marker path and both ways out.
2. Sentinels, prior cleanup and cleanup oracle, `run`, baseline.
3. API setup, each step confirmed by the oracle:
   - `android_student` on `android_hw`: Q1 correct, Q2 text, Submit; the Teacher reviews Q2 `2.5` with `Android feedback.` → `checked` `90.00000000`, official `90.00000000`.
   - `android_classmate` on `android_hw`: Q2 text, Submit → waiting.
   - `android_student` on `android_blitz`: Q1 correct, Q2 text, Submit; the Teacher reviews Q2 `1` with `Android Blitz feedback.` and closes the Blitz → `checked` `75.00000000`.
4. Write the marker. Print the URL, `adb reverse tcp:18009 tcp:18009`, the debug-APK build and install commands with `API_BASE_URL`, the logins, the checklist, and both ways out.

**Checklist (Project Owner)**
- **Student `e2e_s09_android_student`:**
  - Finished Blitz shows the Android Blitz with `Score 75.0` and `Question 2: Android Blitz feedback.`
  - The `android` Topic's Homework card shows `Official score: 90.0`.
  - The Homework detail Results show `Official score: 90.0 (Attempt 1)` and `Attempt 1 · Checked · Score 90.0`.
  - `Open attempt 1` shows `Teacher feedback` with `Android feedback.` under Question 2, and no correct answers.
- **Teacher `e2e_s09_teacher`:**
  - The workspace shows no `Review queue` button.
  - The `android` Homework detail Review card shows `Waiting for review: 1` and `Overdue: 1`, and no `Open review queue` button.

**Complete**
1. Oracle: the Android fixtures are exactly as prepared (the smoke only reads): statuses, scores, official rows, Attempt counts, `review_due_at`.
2. Cleanup and oracle, then `removeSentinels`.
3. Remove the marker.
4. `adb -s <serial> reverse --remove tcp:18009`, then verify it is gone.

**Abandon:** the same verified cleanup without a PASS; remove the marker; print `ABANDONED`.

Which device to use (an emulator or a phone) is asked when the smoke is prepared.

## 13. Windows Runner — `run_stage9_windows_e2e.ps1`

**Invocation**

```text
run_stage9_windows_e2e.ps1 -FlutterExecutable <repo>\frontend\.fvm\flutter_sdk\bin\flutter.bat -ApiPort 18009
```

**Preconditions:** `STAGE9_E2E_PASSWORD`; PostgreSQL running; image built; `docker/.env` present.

**Ordered plan**, enforced step by step as in Stage 8. Before the plan starts: the mutex, the marker refusal, the Flutter pin, the clean checkout, and HEAD recorded.

1. `runtime_guard`: Initialize, live guard, exclusive database.
2. `pure_verifiers`: the four `verify_stage9_*` scripts; the runtime-guard verifier includes its live part.
3. `sentinel_capture`.
4. `prior_manifest_cleanup` on the real disk.
5. `prior_cleanup_oracle`.
6. `seeder_test`.
7. `fresh_seed`.
8. `baseline_oracle`.
9. `test_files`.
10. `api_setup`: §9.1, four scenarios.
11. `review_transport`: §9.2.
12. `scheduled_checking`: §9.3.
13. `windows_flow`: §9.4, 6 checkpoints.
14. `post_ui_api`: §9.5, three scenarios.
15. `post_flow_oracle`.
16. `restart`, then `post_restart_oracle`: §9.6.
17. `final_cleanup`, `cleanup_oracle`, `remove_sentinels`.

**After the plan:** remove the local temp roots, check that the whole plan ran, run the exclusive-database check, and confirm the checkout is unchanged.

**Evidence file:** `%TEMP%\testlabuz-stage9-evidence-<sha12>-<yyyyMMddTHHmmssZ>.json`. It contains:
- `sha`, `api_port`;
- `ui` (`ui-evidence.json` plus the runtime ids);
- `scenarios{name: {result: "PASS", details}}`;
- `scheduler{outputs}`;
- `rejected_keys` (a count);
- `checkout_clean`, `executed_steps`, `duration_seconds`.

It holds no password, token or key, and it is not committed.

**Log lines:** `Stage9Run:`, `Stage9RuntimeGuard: PASS …`, `Stage9Checkpoint: PASS <name>`, `Stage9WindowsUiProcess: PASS exit_code=0`, `Stage9Scenario: PASS <name>`, `Stage9ScheduledCommand: PASS <command>`, `Stage9AutomatedEvidence: PASS …`.

**`finally`:** revoke API sessions, remove temp roots, null the password, release the mutex. It prints "state preserved" only if state was touched.

## 14. Files

New, and nothing else:
- the 15 files of §6;
- this contract.

Bookkeeping: `tasks/STAGE_09_TASK_INDEX.md`, `tasks/README.md`. The execution record in PR 2 goes to the index.

**Production code, packages, platform files, `docker/` and Stage 8 assets are not changed.** A needed change to any of them is a conflict to report.

## 15. Focused Asset Verification (PR 1)

1. `Stage9E2eSeederTest` inside the Stage 9 container: all pass (`timeout --kill-after=10 900`).
2. The pure verifiers print PASS: runtime guard (with its live part), oracle, API security, test files.
3. `flutter analyze` and `dart format --output=none --set-exit-if-changed` on the two Dart files.
4. `git diff --check`.
5. Deliberate breaks: each oracle assertion family and each negative-probe check is broken once in a scratch copy and must fail. The count is recorded.
6. A development shakeout on the live stack runs §9.1–§9.3 and §9.5 through the API.

   It is not evidence, because the UI is not involved. A dry run of the Windows flow up to the first checkpoint is also not evidence.

One phpunit at a time. Reviewers run nothing that touches Docker or the database.

## 16. Integration Harness Preflight

Before PR 1 is opened, an independent fresh-context reviewer reads this contract, the assets and the directly relevant production code. The reviewer reports P1/P2/P3 findings on:
- run safety (guard, exclusivity, ownership, cleanup, secrets, sentinels, scheduled-command safety);
- expectation correctness against the production contract (arithmetic, states, texts, keys);
- determinism (waits, keys, scoped finders);
- failure classification.

P1 and P2 findings are fixed and re-reviewed. P3 findings are fixed, or recorded with a reason. Preflight PASS = P1 = 0, P2 = 0.

## 17. Acceptance Criteria

- [ ] §15 passes; preflight PASS; PR 1 merged.
- [ ] The Windows run on the merged `main` prints `Stage9AutomatedEvidence: PASS`: 17/17 steps, 6/6 checkpoints, every §9 scenario PASS, the checkout clean and unchanged.
- [ ] The Android manual smoke is PASS: the owner reports the checklist, and Complete prints `Stage9ManualSmokeOracle: PASS` and `Stage9ManualSmokeCleanup: PASS`.
- [ ] The final integration review finds P1 = 0, P2 = 0. Each finding is classified.
- [ ] The execution record is delivered (PR 2).

## 18. Observations for the Closure Review

- The backend has no real-concurrency test of exception grant against checking, or of the `attempts:check-frozen` sweep against a Submit. The lock order is documented and unit-tested (`S09-DOC-001` §8).
- The Stage 8 E2E harness no longer matches the Stage 9 backend: its cleanup does not know `official_task_scores`, and its sentinel identity expects an unchecked Attempt. It is historical and not maintained.
