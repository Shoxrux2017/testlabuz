# Implementation Contract: S10-BE-PHASE-2-FIX-001 — Stage 10 Backend Test Hardening

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-BE-PHASE-2-FIX-001` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Backend tests only` |
| Status | `Approved` |
| Source | `S10-BE-PHASE-2` §7 P3 `A-1`, `A-2`, `B-1`, `B-2`, `C-1`, `C-2`, `D-4` |
| Owner decision | `S10-BE-PH2-D1` = A (2026-10-03): one small test-only task before the frontend plan |
| Implementation baseline | `origin/main` `aaaad32` |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |

## 2. Goal

Add the tests the Phase 2 reviewers found missing, without any production change. Each new test must fail
when the behavior it protects is removed.

## 3. Scope

Included: the tests of §4. Non-goals: any change under `backend/app`, `routes`, `database`, `frontend`, or
to an existing assertion other than extending it.

## 4. Tests to Add

| Id | Test |
|---|---|
| `A-1` | Reader: a closed `not_completed` snapshot with a ready Homework side (Blitz missing) reads back with the Homework Attempt id, number and score, the Not completed category, `missing_component = blitz` and no final score or method |
| `A-2` | Reader: an official row that names another Attempt or score than the live evaluation makes that side not ready; a missing acceptable difference gives `waiting_for_settings` |
| `B-1` | Release rule order: an already Student-released result whose window reopened returns `200` without change and counts as `already_done` in bulk; the same for an already Parent-released result the Student can no longer see; an already Student-released result after the Student mode turns `automatic` returns `409 manual_release_not_allowed` |
| `B-2` | The calculated list item is asserted in full (both sides, comment, visibility) |
| `C-1` | The Student result read, the Parent read, the Student Topic detail and the Teacher list and detail each run their result reads inside exactly one `StudentBlitzReadSnapshot::read` |
| `C-2` | API level: a closed unreleased result stays hidden from the Student; a result closed at archive without an official Blitz stays hidden under automatic release; a Parent reads a closed result; a Parent gets `404` for an invalid Topic and for a child without Topic access, also in hidden mode |
| `D-4` | The official Blitz Start of a Student who is not a group member uses the persisted cohort and leaves the recipients unchanged |

## 5. Acceptance Criteria

- [ ] Every §4 test exists and passes; each is shown to fail when the protected behavior is removed
      (mutation check).
- [ ] No production file changes.
- [ ] Independent fresh-context review `PASS` (P1 = 0, P2 = 0).

## 6. Verification

```text
pint --test; phpunit on every changed test file; the mutation check; git diff --check
```
