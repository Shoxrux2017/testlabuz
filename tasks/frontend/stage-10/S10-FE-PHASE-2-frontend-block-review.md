# Phase 2 Read-Only Block Review — Stage 10 Frontend

## 1. Review Metadata

| Field | Value |
|---|---|
| Task ID | `S10-FE-PHASE-2` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Block | `Frontend` (`S10-FE-001` … `S10-FE-005`) |
| Review mode | `Read-only` |
| Review date | `2026-10-04` |
| Stage index | `tasks/STAGE_10_TASK_INDEX.md` |
| Audited `origin/main` | `000154b8dcd7e0ec1069050ce20710db7c431ab1` |
| Local `main` / ahead-behind | `000154b` / `0/0`, clean |
| Block diff | `git diff 15c9a71...000154b -- frontend` (110 files, +14078/−94), plus `docs/02`, `03`, `04`, `06`, `07` |
| Review and verification executor | Claude; every command run locally |
| Verdict | `PASS` (§8) |

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Backend checkpoint | Pass | `S10-BE-PHASE-2` `PASS`; `FIX-001` delivered (PR #322, `main` `15c9a71`) |
| Frontend plan approved | Pass | Owner `S10-FE-D1` = B; plan approved (index §7 rows `6`-`11`) |
| All block tasks accepted | Pass | `S10-FE-001` … `005`, review `PASS` each (index §11) |
| All block tasks delivered | Pass | PRs #323–#327 merged; `main` `000154b` |
| `main == origin/main`, `0/0`, clean tree | Pass | `git rev-parse HEAD origin/main`, `git status` |

## 3. Review Inputs

- The five task contracts in `tasks/frontend/stage-10/`.
- Root and frontend `AGENTS.md`.
- Index §§4-5 (owner and technical decisions), §8 and §10.
- `tasks/README.md` §10 (checklist) and §11 (severity).
- The backend routes, requests, resources and actions the contracts name.
- The current code and tests.

## 4. Audited Block Inventory

| Merge | Task | Delivered outcome | Frontend files |
|---|---|---|---|
| `e979a46` (#323) | `S10-FE-001` | The seven Stage 10 error codes; the Student Topic result card; `homework_not_submitted` and `result_closed` Start messages | 24 |
| `55883ee` (#324) | `S10-FE-002` | Teacher results card on the Topic detail, results list (filters, counts, pages) and result detail, desktop and mobile | 33 |
| `b204628` (#325) | `S10-FE-003` | Release single/bulk (both surfaces), comment and close single/bulk (desktop), confirmations, skip report, error mapping | 20 |
| `89d94e2` (#326) | `S10-FE-004` | `S10-D8` activation note, archive warning, review `result_closed`, `CL9-5` row filters, a result's link to the Student's submissions, related-view reloads | 24 |
| `000154b` (#327) | `S10-FE-005` | Carried `FE-PH2` P3: deferred upload held during leave confirmations, `B-2`, `B-3`, `B-4`, `B-5`, `C-3`, `A-2`, `D-3` | 26 |

Every approved task is represented, and no unapproved scope entered the block. `pubspec.yaml`, `pubspec.lock`,
platform folders and generated files are unchanged.

## 5. Review Method

Four independent fresh-context reviewers worked read-only, with one shared brief: the `tasks/README.md` §10
checklist, the severity model and the accepted decisions. None of them ran a build or test command, so the
verification run in §6 was not disturbed.

| Area | Scope |
|---|---|
| A | Student side: `FE-001`; `FE-005` §5.1 (deferred upload hold) and §5.7 (autosave tests); Student effects of `FE-002`…`004` |
| B | Teacher results: `FE-002` (read) and `FE-003` (actions) against the backend |
| C | Cross-feature: `FE-004` and the router as a whole for the Stage 10 routes |
| D | Cross-cutting: the Teacher parts of `FE-005`; architecture, error codes, stale async, role isolation, test quality, scope, docs |

All four reported **P1 = 0, P2 = 0**. Confirmed across the block:

- **API integration.**
  - The nine Teacher paths, the Student result path, query parameters and bodies match the backend
    (`routes/api.php`, the strict requests). POST bodies are `{}`.
  - The comment PUT sends the trimmed text or null. The trim uses the backend's Unicode whitespace set, and the
    limit counts code points.
  - Every `409` whitelist matches what its backend action throws. Only an exact documented failure is
    definite; anything else is an unknown outcome that is reconciled by a re-read.
  - The DTOs are strict and their invariants agree with the backend calculator, visibility rule and closed
    snapshot.
- **Backend authority.** The client never computes a status, score, category or eligibility. Buttons come from
  the server's flags and are checked again in the controllers. The `S10-D8` note is information only; the
  server's `409` decides.
- **Privacy (`S10-D2`).** No Student or Teacher screen shows D, T, consistency or `category_score`. Nothing
  unreleased reaches the Student.
- **`S10-FE-D1`.** Close, close-all and the comment are refused on mobile in the controllers, not only hidden.
- **Routing and roles.**
  - The predicates are exact, ids canonical; a query string or fragment is redirected.
  - The result-reviews route is desktop-only and maps to the result detail on mobile.
  - The bootstrap keeps the result locations.
  - A Student or Parent never reaches a Teacher result or review path.
- **Session safety and stale async.** Every new controller follows the session key, generation and dispose
  pattern, and clears itself on the four session failures. Mutations keep their controller alive until the
  answer. Every cross-feature reload checks `ref.exists` and the owning session. No reload triggers another.
- **Deferred upload hold.** Every order of the scheduled upload against hold, release and Leave was traced: no
  double upload and no lost file.
- **Tests.** Mutation checks killed every planted defect: 7/7, 25/25, 31/31, 27/27, 20/20. No test file was
  deleted. Every changed or removed pre-existing assertion traces to a contract change. There are no sleeps and
  no real time or network.
- **Docs.** `docs/02`, `03`, `04`, `06` and `07` match the code and the owner decisions.

## 6. Verification (`000154b`)

| Check | Command | Result |
|---|---|---|
| Full frontend suite | `flutter test` (TEMP on G:) | PASS — 4022 tests, 182 s, exit 0 |
| Static analysis | `flutter analyze --no-pub lib test` | PASS — no issues |
| Format | `dart format --output=none --set-exit-if-changed lib test` | PASS — 942 files, 0 changed |
| Windows debug build | `flutter build windows --debug` | PASS — `build\windows\x64\runner\Debug\testlabuz_client.exe`, 23 s |
| Android debug build | `flutter build apk --debug` | PASS — `build\app\outputs\flutter-apk\app-debug.apk`, 34 s |
| Whitespace | `git diff --check 15c9a71...000154b` | PASS |

The tracked tree stayed clean after the builds.

## 7. Findings

P1 = 0, P2 = 0, P3 = 11.

| Id | Kind | Finding | Disposition |
|---|---|---|---|
| `D-1` | Stale view | The Teacher results card and list are not reloaded after an official Blitz close, a Homework close or an official designation change. The Topic detail stays mounted under the Blitz and Homework routes, so after closing the official Blitz the card still shows "Waiting for Blitz" counts and "Open results" shows the cached rows. The list has a Refresh button, and the result detail and every action read the server. `FE-004` §5 named only activation, archive and review saves, so the gap is in the contract | Owner decision (§10) |
| `A-1` | Stale view | The Student Topic result card is not reloaded after a Homework Submit or a Blitz finish, for the same reason. After submitting the Homework the card still says "Waiting for Homework" until "Refresh result" is tapped. `FE-001` asked only for the card's own Refresh | Owner decision (§10) |
| `B-2` | UX | The results list and the result detail offer Retry on a `404`, which cannot succeed (for example, a Teacher who no longer teaches the group). The card already hides it | Owner decision (§10) |
| `C-1` | Accessibility | Every row's filter menu is named "Filter by", so a screen reader hears the same name 25 times | Owner decision (§10) |
| `C-4` | Accessibility | The activation note changes in place when the Homework read finishes, without a live-region announcement. The "not confirmed" text already covers the worst case | Owner decision (§10) |
| `B-1` | Message | A `422` on release or close would show the comment wording. The client always sends `{}`, which the backend accepts, so it is unreachable (accepted in the `FE-003` review) | Accepted |
| `C-2` | Efficiency | After an official activation, the Homework detail reload is thrown away when the Homework screen is not open (one extra request; the "request churn" noted in the `FE-004` review) | Accepted |
| `A-2` | Tests | A stale-session Student test asserts `isNot(10.0)` instead of the loading state and a null result | Owner decision (§10) |
| `A-3` | Tests | The Blitz deferred-hold tests lack two cases the Homework tests have (a hold after the scheduling rebuild; release before writes are accepted again, and twice). The code is the same | Owner decision (§10) |
| `C-3` | Tests | The non-Teacher routing test covers a Student on two result paths only; a Parent and the result-reviews path are not exercised (the generic gate is correct; `FE-005` `D-3` covers the review paths) | Owner decision (§10) |
| `D-2` | Bookkeeping | Index row `10` still read "PR open"; nothing recorded where `C-4` and `D-4` (Stage 9) go next | Fixed in this record's PR (index §7, §10) |

## 8. Verdict

**`PASS`**:
- P1 = 0 and P2 = 0;
- the full frontend suite, analysis, format and both target builds pass;
- no unresolved architecture, API integration, session, routing, state or cross-task conflict remains.

`PASS` applies to `main` `000154b`. Under the approved Stage 10 process, the next step is the report to the
Project Owner, followed by a wait. Integration starts only after the owner's reply.

## 9. Carried Items

| Item | Source | Target |
|---|---|---|
| `C-4` (submission detail file size, controller boilerplate), `D-4` (Student `scoreVisible` duplicates `officialScore != null`) | `S09-FE-PHASE-2`, kept by `S10-FE-005` §2 | Stage 10 closure names the target Stage |
| `refreshAfterReview` reused for the activation reload (the name no longer says what it does) | `S10-FE-004` review #2 | Stage 10 closure |
| Undo in a read-only review field during a save | `S10-FE-005` review | Accepted |
| Backend `D-1` (docs pair-lock wording), `D-2` (Stage 8 harness), `D-3` (integration seeder owns `topic_results`) | `S10-BE-PHASE-2` §7 | Stage 10 integration and closure |

## 10. Owner Decision Requested

Whether the user-visible P3 findings (`D-1`, `A-1`, `B-2`, `C-1`, `C-4`), with or without the test items
(`A-2`, `A-3`, `C-3`), are fixed as one focused frontend task before integration, or are carried. The `PASS`
does not depend on them.
