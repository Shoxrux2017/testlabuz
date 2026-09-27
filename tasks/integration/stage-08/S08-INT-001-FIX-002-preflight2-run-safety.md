# Focused Fix Contract: S08-INT-001-FIX-002 — Preflight #2 Run-Safety Findings

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-INT-001-FIX-002` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | `S08-INT-001` Integration Harness Preflight #2 on audited `main` `87e52d3` — `PASS` with three P3 findings |
| Findings fixed | `PF2-P3-1`, `PF2-P3-2`, `PF2-P3-3` |
| Project Owner decision | `INT-D5` = option 2 done as option 4 (Б as Г) (2026-09-27): fix before the run, prepared while the owner sets the password |
| Area | Integration harness only |
| Implementation | Claude |
| Delivery | One PR carrying this contract, the index record and the code (owner-approved to avoid an extra merge cycle); Project Owner merges |

## 2. Goal

The Windows run and the Android manual smoke run on one final commit without the three known
run-safety gaps. No production code, API, route, schema, fixture identity or verification semantics
change.

## 3. Exact Implementation Contract

### 3.1 `PF2-P3-1` — every seeder refusal reaches the operator

The four fail-closed messages of `Stage8E2eSeeder` that did not match the §5.11 allowlist of
FIX-001 (`\A(?:Static |Unowned )?Stage 8 `) are reworded to start with `Stage 8 `. Their meaning
is unchanged. After the change, every `require(...)` / `RuntimeException` message of the seeder
matches the allowlist. Redaction of a refusal uses the input values locally in the guard, because
`Protect-Stage8Diagnostic` lives in the API layer, which the guard does not load. The effect is the
same.

### 3.2 `PF2-P3-2` — the manual-smoke marker can always be cleared safely

- Completion removes the marker right after the cleanup oracle and `removeSentinels`, before any
  `adb` step, so a device failure after cleanup can no longer leave a marker over an empty state.
- New mode `prepare_stage8_manual_smoke.ps1 -AbandonManualSmoke` withdraws a pending smoke without
  a PASS. It requires the marker, runs the same verified cleanup (cleanup, cleanup oracle with prior
  IDs, sentinel check, `removeSentinels`), removes the marker, and prints
  `Stage8ManualSmoke: ABANDONED`. It cannot be combined with `-CompleteManualSmokeAndCleanup`.
- Every refusal caused by the marker names the marker path and both ways out.
- The runner prints "state is preserved … removed by the next invocation" only if it had started
  changing manifest state. Otherwise it prints `Stage8Run: FAILED before any Stage 8 manifest state
  was changed.`

### 3.3 `PF2-P3-3` — the global Scheduler command is time-bounded

The guarded Scheduler invoker runs `blitz:reconcile-timeouts` under `timeout --kill-after=10 300`
inside the container. Exit code 124 or 137 fails as
`environment/runtime defect: blitz:reconcile-timeouts timed out after 300 s.`

## 4. Expected Files

```text
backend/database/seeders/Stage8E2eSeeder.php
frontend/integration_test/stage8_runtime_guard.ps1
frontend/integration_test/stage8_oracle.ps1
frontend/integration_test/verify_stage8_oracle.ps1
frontend/integration_test/prepare_stage8_manual_smoke.ps1
frontend/integration_test/run_stage8_windows_e2e.ps1
tasks/STAGE_08_TASK_INDEX.md
tasks/integration/stage-08/S08-INT-001-FIX-002-preflight2-run-safety.md
```

## 4A. Acceptance Criteria

- [ ] Every seeder `require(...)` / `RuntimeException` message matches the refusal allowlist.
- [ ] A Scheduler exit code 124 or 137 fails as a timeout; the verifier proves the classification.
- [ ] Completion removes the marker before any `adb` step.
- [ ] `-AbandonManualSmoke` removes a pending smoke's state through the verified cleanup and clears the marker, and refuses without a marker or together with completion.
- [ ] Every marker refusal names the marker path and both ways out.
- [ ] The runner claims preserved state only after it began changing it.

## 5. Focused Verification

- `Stage8E2eSeederTest` inside the Stage 8 container.
- `verify_stage8_oracle.ps1` (a Scheduler exit code 124 must be classified as a timeout).
- `verify_stage8_runtime_guard.ps1 -ApiPort <port>`.
- A scan proving every seeder refusal message matches the allowlist.
- A live development check of the marker flow: prepare → second prepare refused → runner refused → completion without a device refused → both switches refused → abandon (clean state, marker removed) → second abandon refused.
- A deliberate break of the timeout classification must be caught.
- `git diff --check`.

## 6. Evidence Validity

Preflight #2 stays `PASS`. This diff touches only the paths above, which a targeted read-only
re-review confirms before the Windows run.
