# Phase 2 Read-Only Block Review — Stage 9 Frontend

## 1. Review Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-PHASE-2` |
| Stage | `Stage 9 — Checking and Scoring` |
| Block | `Frontend`: `FE-UX-001`, the Flutter parts of `S09-BE-002`, `S09-BE-005B` and `S09-BE-007B`, and `S09-FE-001A` … `S09-FE-004B` |
| Review mode | `Read-only` |
| Review date | `2026-10-01` |
| Stage index | `tasks/STAGE_09_TASK_INDEX.md` |
| Audited `origin/main` (run #1) | `6e58259abbf46952f68f67ca27bea5a1e713805f` |
| Local `main` / ahead-behind | `6e58259` / `0/0`, clean |
| Block diff | `git diff b07bdb1...6e58259 -- frontend` (170 files, +22173/−855) |
| Review and verification executor | Claude (reviewer role since 2026-09-23); every command run locally |
| Run #1 verdict | `NOT ACCEPTED`: one P2 (§7) |
| Follow-up | `S09-FE-PHASE-2-FIX-001` (§8) |

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Backend checkpoint | Pass | `S09-BE-PHASE-2` `PASS` (PR #301, `main` `95992d3`) |
| All block tasks accepted | Pass | `FE-UX-001`, `S09-FE-001A` … `004B` accepted in index §11 |
| All block tasks delivered | Pass | PRs #288, #291, #296, #299 and #302–#310 merged; `main` `6e58259` |
| `main == origin/main`, `0/0`, clean tree | Pass | `git rev-parse HEAD origin/main`, `git status` |

## 3. Review Inputs

- `S09-DOC-001` and the frontend task contracts in `tasks/frontend/stage-09/`.
- The `FE-UX-001` contract.
- Root and frontend `AGENTS.md`.
- Index §4 and §11 (accepted decisions).
- The backend code the contracts name.
- The current code and tests.

## 4. Audited Block Inventory

| Merge | Task | Frontend files |
|---|---|---|
| `4432f27` | `FE-UX-001` Student answer autosave (`S09-D8`, `S09-D8a`) | 49 |
| `9b772b4` | `S09-BE-002` Teacher Homework `review_due_at` parser | 8 |
| `06fe754` | `S09-BE-005B` Teacher `review_summary` parser | 17 |
| `bb6da8b` | `S09-BE-007B` Student result, feedback, `attempt_results` and official-score parsers | 16 |
| `5aaf9a5` | `S09-FE-001A` grant warning, `CL-6`, `CL-7` | 11 |
| `6ed9b7a` | `S09-FE-001B` Homework review deadline | 18 |
| `f3cbefa` | `S09-FE-002A` desktop review queue | 20 |
| `bf6df48` | `S09-FE-002B` task review counts and task queue | 13 |
| `8d401ca` | `S09-FE-003A` submission detail and file download | 19 |
| `1983fdc` | `S09-FE-003B` review save and correction | 14 |
| `473d8a0` | `S09-FE-003C` official-score panel | 15 |
| `c1082e5` | `S09-FE-004A` Student Homework results | 7 |
| `6e58259` | `S09-FE-004B` finished Blitz list | 17 |

## 5. Review Method

Four independent fresh-context reviewers worked read-only. Each had the `tasks/README.md` §10 checklist, the severity model and the accepted decisions.

| Area | Scope |
|---|---|
| A | Student side: `FE-UX-001`, the `007B` parsers, `004A`, `004B` |
| B | Teacher task pages: `001A`, `001B`, `002B`, the `002`/`005B` parsers |
| C | Teacher review surface: `002A`, `003A`, `003B`, `003C` |
| D | Cross-cutting: routing and role isolation, session and stale async, API integration, backend authority, cross-task interactions and regressions, architecture and scope, accessibility |

Confirmed across the block, at P1 = 0:
- **Routing.**
  - Exact predicates and canonical ids.
  - Query strings and fragments are redirected.
  - Review routes are desktop-only.
  - Mobile mapping is correct, the bootstrap keeps the location, and the generic role gate holds.
- **Session safety.** Every new controller follows the session-key, generation and dispose pattern, and clears itself on session failures.
- **API integration.**
  - Strict envelopes and `followRedirects: false`.
  - Canonical ids are checked before transport.
  - Only exact documented failures are definite.
  - The only new error code is `automatic_checking_pending`.
  - No raw server text is shown.
- **Backend authority.** The client only displays scores, visibility, counts and statuses. The one-decimal display is the only client rule (`S09-T3`).
- **Privacy (`S09-D3`, `S09-D5`).** Nothing unreleased or forbidden reaches the Student UI.
- **Regressions.** Every change to a pre-existing test traces to a contract that changed that behaviour.
- **Scope.** `pubspec.yaml`, `pubspec.lock`, platform folders and generated files are unchanged.

## 6. Verification — Run #1 (`6e58259`)

| Check | Command | Result |
|---|---|---|
| Full frontend suite | `flutter test` (TEMP on G:) | PASS — 3774 tests, 177 s, exit 0 |
| Static analysis | `flutter analyze` | PASS — no issues |
| Format | `dart format --output=none --set-exit-if-changed lib test` | PASS — 893 files, 0 changed |
| Windows debug build | `flutter build windows --debug` | PASS — `build\windows\x64\runner\Debug\testlabuz_client.exe`, 22 s |
| Android debug build | `flutter build apk --debug` | PASS — `build\app\outputs\flutter-apk\app-debug.apk`, 36 s |
| Whitespace | `git diff --check b07bdb1...6e58259 -- frontend` | PASS |

## 7. Findings

The four reports held 17 findings: P2 = 1 and P3 = 16. Two P3 findings duplicate others (`D-1` = `C-1`, `D-2` = `C-2`), so 15 are distinct.

| Id | Sev | Finding | Disposition |
|---|---|---|---|
| `C-1` / `D-1` | **P2** | A related-view refresh after a review save is dropped while that view is already loading. The queues and the Homework/Blitz detail then show data read before the save as current. `003B` §2 requires that they show the new state; `003C` fixed the same class for its panel | `FIX-001` item 1 |
| `C-2` / `D-2` | P3 | The review bar overflows on a narrow desktop window with large text: 800×600 at scale 2, 960×540 at scale 2.25 | `FIX-001` item 6 |
| `B-1` | P3 | Review deadline: a 404 on the reconcile read leaves a blocking outcome review that cannot be cleared, so the Homework detail stays locked | `FIX-001` item 2 |
| `A-1` | P3 | Homework: a file chosen while the Attempt is refreshing is dropped silently | `FIX-001` item 3 |
| `A-3` | P3 | Cancelling the leave flush also ends a Submit flush, and the Submit card shows a false "not saved" message | `FIX-001` item 4 |
| `A-4` | P3 | The save status is a live region, so screen readers announce "Saving…/Saved" at every typing pause | `FIX-001` item 5 |
| `A-2` | P3 | No widget test for autosave on focus loss or app pause | Carried (§9 of the fix contract) |
| `B-2` | P3 | The archived conflict message can appear twice (SnackBar and inline) | Carried |
| `B-3` | P3 | A deadline controller test covers a 500 path that the transport cannot produce | Carried |
| `B-4` | P3 | The date pickers assume years 2000–2100 (also the Stage 6 deadline picker) | Carried |
| `B-5` | P3 | Import order nit in two detail screens | Carried |
| `C-3` | P3 | Client-side review validation is not announced, and focus is lost while a save runs | Carried |
| `C-4` | P3 | Maintainability: the size of the submission detail screen file, and controller boilerplate repeated in five controllers | Carried |
| `D-3` | P3 | No router test opens the review paths as another role (the generic gate is correct) | Carried |
| `D-4` | P3 | Student `scoreVisible` duplicates `officialScore != null` in the domain | Carried |

**Owner decision `S09-FE-PH2-D1`** (2026-10-01): fix the P2 together with the five P3 findings that a user can see (`C-2`, `B-1`, `A-1`, `A-3`, `A-4`), and carry the rest.

## 8. Focused Fix

`tasks/frontend/stage-09/S09-FE-PHASE-2-FIX-001-related-refresh-and-ux-defects.md`.

## 9. Verification — Run #2

Pending.

## 10. Verdict

Run #1: `NOT ACCEPTED` (P2 `C-1`). The verdict after the fix is pending run #2.
