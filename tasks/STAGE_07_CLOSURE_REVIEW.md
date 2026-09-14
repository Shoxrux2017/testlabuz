# Stage 7 Closure Review — Student Homework and Submission Flow

## 1. Executed Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-07-CLOSURE` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Status | `Completed` |
| Review date | `2026-09-14` |
| Review owner / result | `ChatGPT Closure Read-Only Review / PASS` |
| Verification model | `Workflow v3 — Lean Verification + Integration Harness Preflight discipline` |
| Planning baseline | `294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Audited accepted product `origin/main` | `3d71a58a375ac4473594c3b7fe79a9ca6de7d099` |
| Local `main` at read-only audit | `3d71a58a375ac4473594c3b7fe79a9ca6de7d099` |
| Ahead/behind | `0/0` |
| Working tree | `Clean` |
| Previous Stage | `Stage 6 — Closed / PASS` |
| Decomposition | `Approved / Delivered` |
| Backend Phase 2 | `PASS` |
| Frontend Phase 2 | `PASS` |
| Integration | `S07-INT-001 — Accepted / Delivered / PASS` |
| Integration Harness Preflight | `PASS` |
| Windows real-stack | `PASS` |
| Android manual smoke | `PASS` |
| Integration cleanup | `PASS` |
| Open findings | `P1=0, P2=0, P3=0` |
| Roadmap acceptance | `PASS` |
| Stage Definition of Done | `PASS` |
| Stage 8 compatibility boundary | `PASS` |
| Stage 9/10 scope boundary | `PASS` |
| Closure verdict | `STAGE CLOSED` |
| Next permitted gate | `Stage 8 planning/decomposition only` |

ChatGPT completed the substantive closure audit and determined that Stage 7
qualifies for `STAGE CLOSED`. This executed record transcribes that approved
result. Closure bookkeeping does not repeat the product review or make new
product, architecture, API, database, security, lifecycle, or verification
decisions.

The planning baseline is historical. The accepted product audited at closure is
`3d71a58a375ac4473594c3b7fe79a9ca6de7d099`. The closure bookkeeping delivery is
separate from that accepted product revision.

## 2. Completed Task Inventory and Delivery

All 16 pre-closure Stage items reached their required final states. Focused
integration findings/corrections belong to `S07-INT-001`; they do not create
additional task IDs.

| Order | Task | Final state | Delivery / evidence |
|---:|---|---|---|
| 1 | `S07-DOC-001` | `Accepted / Delivered` | PR #187; merge `6529ae4b4a114828d0636baec597d10c03ef3164` |
| 2 | `S07-BE-001` | `Accepted / Delivered` | PR #190; merge `86067f9a61864a4d313b7ec8b59ee1217218b612` |
| 3 | `S07-BE-002` | `Accepted / Delivered` | PR #192; merge `a145d7bc9146a0d8470693449961771824663676` |
| 4 | `S07-BE-003` | `Accepted / Delivered` | PR #194; merge `1a7e86d3d08902feab3f004b21754aa7e2f1f98a` |
| 5 | `S07-BE-004` | `Accepted / Delivered` | PR #196; merge `275a1b2087a5d3e5a15c0ef1d3e50bba923236b2` |
| 6 | `S07-BE-005` | `Accepted / Delivered` | PR #201; merge `c03a600a92257a8a64730d603658381fb5ffb854` |
| 7 | `S07-BE-006` | `Accepted / Delivered` | PR #204; merge `c9a347986493ba8ee813984d4e6bc504edd1e5e9` |
| 8 | `S07-BE-007` | `Accepted / Delivered` | PR #207; merge `22c03f4e9aec8a421bd0edbe02756e557f943d60` |
| 9 | `S07-BE-PHASE-2` | `PASS` | Audited revision `4780c56d36816ac0f7b1ab381c28c7387a2804c6`; P1=0, P2=0, P3=0 |
| 10 | `S07-FE-001` | `Accepted / Delivered` | PR #212; implementation `f3f9c6ce9696da60d8113a06e98cef8b447e0485`; merge `252e67b1c43aa21885eb83379d5c0c618d092ca9` |
| 11 | `S07-FE-002` | `Accepted / Delivered` | PR #215; implementation `3985f94b7eca8a7aa02e09213074471ad5374945`; merge `ad2bc12f328cd76797b13655eee030528c3c764e` |
| 12 | `S07-FE-003` | `Accepted / Delivered` | PR #218; final head `ba7f266161ea5ea77dd4bb982c1b521b16ddef7d`; merge `55528f106288527c2443142022ba5df567d019de` |
| 13 | `S07-FE-004` | `Accepted / Delivered` | PR #220; final head `ba9d8401250a7d9318e87332be054b681ac78b8e`; merge `291ee97693cf4ba2242ad30cd39371800760e740` |
| 14 | `S07-FE-005` | `Accepted / Delivered` | PR #222; implementation `947634efd68089b737f6f099fc207081043dbf61`; merge `5fd8e0f21916572c47ad7b901fdc607d75e6b1e8` |
| 15 | `S07-FE-PHASE-2` | `PASS` | Final refreshed evidence after Resume correction; P1=0, P2=0, P3=0 |
| 16 | `S07-INT-001` | `Accepted / Delivered / PASS` | Integration assets PR #225; focused integration findings/corrections PR #226 |

Documentation synchronization review: `PASS`. `S07-DOC-001` aligned Stage 7
execution/finalization with the later Stage 9 checking/scoring boundary. No
additional `docs/01–09` correction is required by closure.

## 3. Backend Phase 2 Evidence

| Check | Accepted result |
|---|---|
| `S07-BE-PHASE-2` | `PASS` |
| Audited revision | `4780c56d36816ac0f7b1ab381c28c7387a2804c6` |
| Findings | `P1=0, P2=0, P3=0` |
| Full backend regression | `PASS` |
| Required backend quality/static/format verification | `PASS` |
| Evidence valid at closure | `Yes — ChatGPT determination` |

The accepted checkpoint covered backend persistence, lifecycle/finalization,
Start/Submit idempotency, authorization/Tenant isolation, private files, and
cross-task concurrency boundaries. No backend test or assertion count is added
because the existing bookkeeping does not provide an exact accepted count.

## 4. Frontend Phase 2 Evidence

`S07-FE-PHASE-2 = PASS`. The final refreshed checkpoint evidence followed the
integration-discovered production Back -> Resume authoritative state restoration
in `b1343a70e0282629dc5280726d6faa4d4fe10f9d`.

| Check | Accepted result |
|---|---|
| Full frontend suite | `2420 passed, 0 failed` |
| `flutter analyze --no-pub` | `PASS / No issues found` |
| Dart format read-only check | `672 files checked, 0 changed` |
| Windows debug build | `PASS` |
| Android debug APK build | `PASS` |
| Stage-wide `git diff --check` | `PASS` |
| Findings | `P1=0, P2=0, P3=0` |
| Evidence valid at closure | `Yes — ChatGPT determination` |

Later accepted Stage 7 changes were integration-harness-only or the final narrow
copy correction recorded below. ChatGPT determined that the accepted Frontend
Phase 2 evidence remains valid.

## 5. Integration Delivery and Focused Corrections

| Delivery | PR | Head | Merge |
|---|---|---|---|
| `S07-INT-001` integration assets | #225 | `48d93471787a9ce570a1e489032e1a8073d0e1d2` | `30e29b0382a05067af2faef4fb0e509bef38aa4f` |
| Focused Stage 7 integration findings/corrections | #226 | `c392e94988d796575f1d39b0b44e1615584d0d4b` | `3d71a58a375ac4473594c3b7fe79a9ca6de7d099` |

PR #226 included the accepted focused sequence:

1. Topic-card E2E locator correction.
2. UUID v7 integration-harness support.
3. Dropdown integration-harness correction.
4. Production Back -> Resume authoritative state restoration.
5. Awaited logout teardown correction.
6. Singular/plural unanswered-question copy correction.

The final automated full-run audited SHA was
`8e6fc73b327baf921e829a2dcf5c4c829ea3a694`.

The later commit `c392e94988d796575f1d39b0b44e1615584d0d4b` was copy-only plus
focused regression coverage. ChatGPT reviewed it and determined that it does
not invalidate Windows real-stack evidence, Android manual smoke, API/security
evidence, persistence evidence, Backend Phase 2, or Frontend Phase 2. No GitHub
workflow run was used as closure evidence for that commit; this record does not
claim that GitHub CI ran for `c392e949`.

## 6. Final Integration Evidence

These are the accepted execution results supplied to ChatGPT's closure audit.
They are recorded here without rerunning the product verification.

| Evidence | Accepted result |
|---|---|
| Integration Harness Preflight | `PASS` |
| Runtime guard | `PASS` |
| Runtime guard matrix | `PASS` |
| Test-file verifier | `PASS` |
| Stage 7 pure oracle | `PASS — 59 checks` |
| Seeder verification | `17 passed, 1544 assertions` |
| Baseline DB oracle | `PASS` |
| API security pure verifier | `PASS — 52 checks` |
| Deadline Read reconciliation | `PASS` |
| Due Teacher Close / deadline precedence | `PASS` |
| Future Teacher Close finalization | `PASS` |
| Global Scheduler candidate guard/reconciliation/idempotency | `PASS` |
| Windows production UI process | `PASS — exit code 0` |
| Main Windows Student Homework flow | `PASS` |
| Authentication/role/assignment/Tenant/privacy matrix | `PASS` |
| Protected Student submission download matrix | `PASS` |
| Start idempotency | `PASS` |
| Nested answer scope | `PASS` |
| Strict transport validation | `PASS` |
| File authority/replacement/no-op | `PASS` |
| Submit operation-scope independence | `PASS` |
| Submit replay | `PASS` |
| Terminal rejection | `PASS` |
| Three-attempt exhaustion | `PASS` |
| Backend restart persistence | `PASS` |
| Post-restart protected replacement download | `PASS` |
| DB/private-file oracle | `PASS` |
| Final automated evidence | `PASS` |

The accepted evidence combines the production Windows Student flow with direct
API/security verification and independent persistence/private-file oracles.
The closure rationale therefore includes backend authority and durable state,
beyond visible UI state alone.

## 7. Android Manual Smoke

| Field | Accepted result |
|---|---|
| Status | `PASS` |
| Confirmed by | `Project Owner` |
| Date | `2026-09-14` |
| Target | `Android emulator, Android 17 / API 37` |
| Safe fixture | `E2E S07 Android Smoke Homework` |
| Manual DB oracle and cleanup | `Stage7ManualSmokeOracleAndCleanup = PASS` |
| Temporary ADB reverse mapping | `Removed` |
| Final `adb reverse` list | `Empty` |

Verified flow:

1. Real Student login.
2. Open assigned mobile Homework.
3. Start Attempt.
4. Save Single Choice.
5. Save Short Written.
6. Confirmation reports 2 of 3 saved and one unanswered.
7. Explicit Submit.
8. Terminal `Submitted by you`.
9. Back to Homework.
10. Allowed attempts = 3; Used = 1; Remaining = 2.

The Android wording issue observed during manual smoke was resolved by
`c392e94988d796575f1d39b0b44e1615584d0d4b` and is not an open finding.

## 8. Guarded Cleanup

| Required cleanup | Accepted result |
|---|---|
| Manifest-owned Stage 7 DB fixtures removed | `PASS` |
| Manifest-owned private blobs removed | `PASS` |
| Generated local Stage 7 files removed | `PASS` |
| Unrelated sentinel state preserved | `PASS` |
| Temporary Android reverse mapping removed | `PASS` |

The external dedicated Docker/private named volume is allowed to remain
provisioned. This record does not claim that it was deleted.

## 9. Roadmap Acceptance and Stage Definition of Done

The approved roadmap criterion is that a Student can complete up to three valid
Homework attempts while each attempt is preserved and deadline, timezone,
relationship, Institution, and file-limit rules are enforced. ChatGPT's closure
audit mapped that criterion to the accepted implementation, both Phase 2
checkpoints, Windows real-stack/API/persistence evidence, and Android smoke.

| Closure criterion | Result |
|---|---|
| Assigned Student can start Homework | `PASS` |
| Unassigned Student is blocked | `PASS` |
| Exactly 3 normal Homework attempts | `PASS` |
| Fourth normal attempt blocked | `PASS` |
| At most one in-progress Attempt | `PASS` |
| Start create/resume works | `PASS` |
| All 9 Question types represented | `PASS` |
| All 8 non-file answer mutations work | `PASS` |
| Private file upload/replacement/download works | `PASS` |
| Explicit partial and zero-answer Submit supported | `PASS` |
| Terminal Attempt immutable | `PASS` |
| Deadline authority enforced server-side | `PASS` |
| Teacher-close auto-finalization works | `PASS` |
| Deadline takes precedence when due | `PASS` |
| Second/third Attempts remain separate history | `PASS` |
| Parent cannot submit | `PASS` |
| Cross-Institution access denied | `PASS` |
| Direct UUID knowledge does not widen access | `PASS` |
| Effective Student file size/type protection works | `PASS` |
| Desktop/mobile behavior verified | `PASS` |
| Frozen `assessment_students` assignment remains authoritative | `PASS` |
| First official Homework Attempt locks official pair/cohort meaning | `PASS` |
| No Stage 9 scoring/checking | `PASS` |
| No Stage 8 Blitz execution | `PASS` |
| No Stage 10 final Topic result | `PASS` |
| Roadmap acceptance | `PASS` |
| Stage Definition of Done | `PASS` |

No blocking regression is known.

The audit rationale preserves the established Stage boundary: Stage 7 captures
and freezes Student Homework work. Explicit Submit and automatic
deadline/Teacher-close finalization preserve saved work as terminal execution
history; checking/scoring belongs to Stage 9. Frozen assignment and the first
official Attempt preserve Homework/cohort meaning. Stage 8 Blitz compatibility
is `PASS`, and the Stage 9/10 scope boundary is `PASS`.

## 10. Final Closure Findings

No findings.

P1 = 0
P2 = 0
P3 = 0

## 11. Closure Verdict and Evidence Validity

```text
Closure Read-Only Review = PASS
Closure verdict = STAGE CLOSED
Stage 7 status = Closed / PASS
Next permitted gate = Stage 8 — Blitz Task Workflow planning/decomposition only
```

Stage 8 implementation is not authorized by this closure.

ChatGPT determined that the accepted Backend Phase 2, Frontend Phase 2,
integration, Windows, Android, API/security, and persistence evidence remains
valid. Closure bookkeeping does not require a product verification rerun.
No backend/frontend tests, Flutter analysis/source formatting, Windows/Android
build, integration runner, Android smoke, or Docker fixture setup is rerun for
this bookkeeping delivery.

## 12. Closure Bookkeeping Delivery and Post-Merge Gate

The authorized closure bookkeeping branch is `docs/stage7-closure`, created
from exactly `3d71a58a375ac4473594c3b7fe79a9ca6de7d099` after verifying local
`main == origin/main`, ahead/behind `0/0`, and a clean working tree.

Delivery is through a new closure-only PR to `main`, titled
`docs(stage7): close student homework and submission flow`. Codex is explicitly
assigned the bookkeeping commit, branch push, and PR creation. PR merge is not
assigned to Codex.

The closure change is limited to:

- `tasks/STAGE_07_CLOSURE_REVIEW.md` — executed closure record.
- `tasks/STAGE_07_TASK_INDEX.md` — completed task/checkpoint/integration statuses.
- `tasks/README.md` — current Stage 7 closure summary, preserving Stage 0–6 history.

Bookkeeping verification consists of `git diff --check`, Git status and exact
three-file diff inspection, placeholder checks, and focused review for
contradictory Stage 7 statuses. No production/test, `docs/01–09`, dependency,
lock, platform, integration asset, generated artifact, or secret belongs in this
closure PR.

Final post-merge `main` synchronization is a Project Owner/ChatGPT verification
gate after the closure-only PR merges. That gate verifies the actual resulting
local `main` and `origin/main`, ahead/behind `0/0`, a clean working tree, and the
three closure records on `main`. Its result and actual merge SHA are recorded
after merge; no future merge SHA is fabricated here. The audited accepted
product SHA above remains the product evidence reference.
