# TestLabUz — Final Cross-Document Consistency Audit

## Verdict

**PASS — `01–09` are LOCKED FOR MVP IMPLEMENTATION.**

The final read-only audit found no remaining business-rule blocker, cross-document mismatch, or contract-critical decision gate. The final Homework-deadline rule was approved and propagated before this audit.

## Scope

Audited files:

1. `01-business-overview.md`
2. `02-user-roles.md`
3. `03-features.md`
4. `04-user-flows.md`
5. `05-business-rules.md`
6. `06-roadmap.md`
7. `07-architecture.md`
8. `08-database.md`
9. `09-api-contracts.md`

## Confirmed consistency

The audit confirmed that the documents use one consistent MVP contract for:

- five roles and multi-institution isolation;
- exactly three normal Homework attempts and highest-valid-completed official Homework score;
- deterministic earliest-attempt tie-break for equal highest Homework scores;
- one normal Blitz attempt plus at most one Student-specific Teacher-approved exception;
- synchronized/individual whole-Blitz timing with no per-question timer;
- Blitz timeout auto-finalization;
- Homework deadline auto-finalization with `homework_deadline_auto_submit`;
- Teacher task-close auto-finalization with `task_closed_auto_finalize`;
- Multiple-choice selection cap and correct-selected/total-correct partial credit;
- deterministic automatic Short Written normalization;
- positive scoreable-points requirement before Homework/Blitz activation;
- unrounded Homework–Blitz calculation, one-decimal display, and integer `category_score` using `.0–.5` down / `>.5` up;
- whole-group-only official Homework/Blitz with one snapshotted Topic cohort;
- new-Institution safe operational initialization and explicit Institution Admin educational-policy configuration;
- mandatory first-login password change for administrator-created accounts;
- Student/Parent release-policy hierarchy and separation of calculation from visibility;
- terminal-state-only Topic Result closure;
- 25 MB learning-material / 15 MB Student-submission platform maxima;
- UTC authoritative instants plus Institution IANA timezone;
- idempotent Institution activate/deactivate;
- required `Idempotency-Key` contract for the five approved high-risk mutations;
- Laravel/server authority for timing, attempts, scoring, scope, and result calculation.

## Final Homework deadline contract

When an authoritative Homework deadline arrives while an Attempt is `in_progress`:

1. New attempts and further Student writes are blocked.
2. The saved Attempt is automatically finalized.
3. Unanswered Questions/components receive zero.
4. Saved answers are evaluated normally.
5. Manual-review answers remain pending Teacher review.
6. `finalization_reason = homework_deadline_auto_submit`.
7. `submitted_at` remains null and `finalized_at` records server finalization.
8. Never-started Students receive no fabricated Attempt.
9. Unused remaining Homework attempts become unavailable.
10. Once fully checked, the auto-finalized Attempt remains eligible for normal highest-valid-completed Homework official-score selection.
11. Laravel Scheduler and request-time reconciliation use the same idempotent server action; scheduler latency never extends write eligibility beyond the authoritative deadline.

## Lock rule

From this point, Codex must not change product behavior while implementing a task. If a behavior needs to change, update the relevant `01–09` contracts first, re-run the affected consistency checks, and only then update implementation tasks/code.

## Next step

1. Create root and project-level `AGENTS.md`.
2. Create `tasks/backend`, `tasks/frontend`, and `tasks/integration`.
3. Close Roadmap Stage 0.
4. Decompose Stage 1 into small Codex tasks with exact files, acceptance criteria, tests, and non-goals.
