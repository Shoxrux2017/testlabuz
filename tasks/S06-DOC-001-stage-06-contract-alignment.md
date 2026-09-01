# S06-DOC-001 — Stage 6 Homework and Staged Result-Pair Documentation Alignment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-DOC-001` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Documentation / contract alignment` |
| Status | `Approved` |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Depends on | Approved Stage 6 decomposition and contracts |
| Blocks | `S06-BE-001` implementation |
| Production code changes | `Forbidden` |
| Schema/API implementation changes | `Forbidden` |
| Verification | `Documentation diff only` |
| Delivery execution | `Project Owner / Codex only as exact documentation editor` |

This task synchronizes already-approved Stage 6 behavior into the locked product/technical documentation before production implementation begins.

It does **not** reopen product design.

Codex must not read the affected documents to make or reinterpret decisions.
All required decisions are stated below. Codex may inspect the exact local text only to place the prescribed edits safely.

---

# 2. Goal

Remove the remaining documentation assumption that the official Homework and official Blitz must both already exist before a Topic result-pair row can exist.

The approved staged contract is:

```text
Stage 6:
official Homework can exist first
topic_result_pairs.homework_assessment_id = NOT NULL
topic_result_pairs.blitz_assessment_id = NULL

Stage 7:
first official Homework Attempt may lock the Homework side/cohort
locked_at may become NOT NULL while blitz_assessment_id is still NULL

Stage 8:
the official Blitz fills the existing NULL blitz_assessment_id
the same topic_result_pairs row is completed
the locked Homework side is not replaced
```

No fake/placeholder Blitz is allowed.

---

# 3. Documents in Scope

Review and align exactly:

```text
docs/02-user-roles.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
```

Also perform **read-only consistency checks** on:

```text
docs/01-business-overview.md
docs/03-features.md
```

Change `01` or `03` only if their current wording explicitly requires both official tasks to exist before the Homework side can be designated or activated.

General statements that the final MVP result uses one official Homework + one official Blitz are still correct and must not be removed.

---

# 4. Authoritative Stage 6 Result-Pair Contract

The documentation must consistently state all of the following.

## 4.1 Final MVP pair cardinality

For final Topic result calculation:

```text
exactly one whole-group Homework
+
exactly one whole-group Blitz
```

form the official result-bearing pair.

Selected-Student Homework/Blitz tasks are practice-only.

## 4.2 Staged construction

The pair is built progressively.

Stage 6 may create:

```text
Topic result-pair row
homework_assessment_id = official Homework UUID
blitz_assessment_id = NULL
```

before any Blitz exists.

This is a valid persisted state, not an incomplete-data error.

## 4.3 No placeholder Blitz

Do not create:

- fake Assessment rows;
- placeholder Blitz rows;
- temporary official-pair tables;
- duplicate Topic result-pair rows.

## 4.4 One row per Topic

There is at most one `topic_result_pairs` row per Topic.

Stage 8 completes that existing row by filling the Blitz side.

## 4.5 Whole-group rule

The official Homework must use:

```text
assignment_mode = group
```

The future official Blitz must also use:

```text
assignment_mode = group
```

Selected-Student tasks cannot be official.

## 4.6 Official cohort

The common official cohort is the persisted Student set belonging to the first activated official whole-group task.

For Stage 6 Homework-first sequencing:

- if official Homework is designated while draft, its activation creates the normal Group recipient snapshot and establishes the official cohort;
- if an already-active eligible whole-group Homework is designated before any Attempt, its existing persisted Group recipient snapshot becomes the official cohort;
- current Group membership changes after that snapshot do not silently rewrite the official cohort;
- Stage 8 must reuse the same cohort for the official Blitz.

Do not require a non-existent Blitz recipient snapshot to be created in Stage 6.

## 4.7 Lock semantics

Before Student activity, the Teacher may replace the official Homework when the backend eligibility rules allow it.

When the first official Homework Attempt begins in Stage 7:

```text
topic_result_pairs.locked_at
```

locks the Homework designation/cohort meaning.

A valid staged row may therefore be:

```text
homework_assessment_id = UUID
blitz_assessment_id = NULL
cohort_snapshotted_at = timestamp
locked_at = timestamp
```

This is valid.

## 4.8 Stage 8 completion exception

Stage 8 may perform:

```text
blitz_assessment_id:
NULL -> official Blitz UUID
```

even when:

```text
locked_at IS NOT NULL
```

provided the Stage 8 official-Blitz and cohort rules pass.

This operation is:

```text
pair completion
```

not:

```text
replacement of the locked Homework side
```

Stage 8 must not clear `locked_at`, replace the official Homework, or change the locked cohort.

---

# 5. `docs/02-user-roles.md`

Preserve the existing role rule that:

- one official whole-group Homework and one official whole-group Blitz are used for the final result;
- selected-Student tasks are practice-only;
- Teacher owns designation inside authorized scope.

Add/adjust the official-pair explanation so it explicitly says:

> The official pair may be assembled progressively. The Teacher may designate the whole-group official Homework before the official Blitz exists. The Topic-level result-pair row keeps the Homework side while the Blitz side remains empty until the Blitz stage. When the first official task becomes active, its persisted whole-group recipient snapshot establishes the common official cohort. The later official task must reuse that cohort. Once Student attempt activity locks the official Homework/cohort, the Homework side cannot be replaced; the later addition of the previously missing official Blitz completes the same pair and is not a replacement.

Do not change role permissions beyond this clarification.

---

# 6. `docs/04-user-flows.md`

Update the Teacher Homework / official-pair flow.

The Homework flow must make the sequence explicit:

```text
1. Teacher creates Homework.
2. Teacher configures assignment, deadline and Questions.
3. Teacher may designate an eligible whole-group Homework as official.
4. The official Blitz does not need to exist yet.
5. If the official Homework activates first, its recipient snapshot establishes the official cohort.
6. Student Homework Attempt execution begins only in Stage 7.
7. Once official Homework Student activity begins, the Homework designation/cohort cannot be meaning-changing replaced.
8. Stage 8 later designates/fills the official Blitz in the existing pair and reuses the same cohort.
```

Preserve the final product rule that one Homework + one Blitz are eventually used for Topic comparison.

Do not move Student Homework execution into Stage 6.

---

# 7. `docs/05-business-rules.md`

Keep existing:

```text
BR-TOP-004
BR-TOP-004A
```

but align them with staged construction.

## 7.1 `BR-TOP-004`

The rule must continue to say that the final MVP Topic result uses:

```text
one whole-group Homework
one whole-group Blitz
```

Add:

> The two official relationships do not need to be created at the same time. The Topic may first have only its official Homework designated; the official Blitz relationship is added later to the same Topic result-pair record.

## 7.2 `BR-TOP-004A`

Replace any wording that requires recipient rows for **both** official assessments to be created when only the first task exists.

Required rule:

> The first activated official whole-group task establishes the common official Student cohort from its persisted recipient snapshot. If the official Homework is the first task, Stage 6 stores that cohort without fabricating a Blitz or Blitz recipient rows. When the official Blitz is later designated/activated, it must use exactly the same cohort. Later Group membership changes do not rewrite the official cohort.

## 7.3 Lock rule

Clarify:

> Student attempt activity locks the already-designated official task/cohort meaning. A previously absent second official task may still be attached later when it satisfies the same Topic and cohort rules; this is completion of the pair, not replacement of locked work.

Do not weaken the existing final-result rules.

---

# 8. `docs/06-roadmap.md`

Preserve the Stage 6 acceptance criterion and final MVP pair requirement.

Add a Stage-boundary clarification under Stage 6 Official Homework Designation:

```text
Stage 6 implements the Homework side of the Topic result pair.
The official Homework may be designated before the official Blitz exists.
The Topic result-pair persistence therefore permits a null Blitz reference
until Stage 8.
No placeholder Blitz is created.
```

Add to the Stage 8 dependency/boundary:

```text
Stage 8 completes the existing Topic result-pair row by filling the official
Blitz reference and reusing the official cohort established by the first
activated official task.
```

Do not change Stage 6 goal:

> A Teacher can create a valid active homework assignment using every supported MVP question type without violating topic, group, or institution boundaries.

---

# 9. `docs/07-architecture.md`

Align the assessment/result architecture.

Required architectural text:

> `topic_result_pairs` is the Topic-level identity of the eventual official Homework–Blitz pair. The aggregate may be persisted in a staged state with the official Homework present and the Blitz reference absent. This allows Stage 6 Homework authoring to establish official Homework/cohort identity without creating a fake Blitz. Stage 8 fills the same aggregate with the official Blitz.

Cohort:

> The first activated official whole-group task establishes the common persisted cohort. A later official task must reuse that exact cohort.

Lock:

> The pair lock prevents replacement of already meaningful official work/cohort. It does not prohibit the one-time completion of an absent Blitz side that satisfies the locked Topic/cohort contract.

Do not change the eventual Result Engine rule requiring both official scores before final Topic calculation.

---

# 10. `docs/08-database.md`

This document has the mandatory schema change.

## 10.1 `assessment_students` official-cohort explanation

Replace any wording equivalent to:

```text
when the first official assessment activates,
insert the same Student set into both official assessments
```

with:

> For the official Topic result-bearing relationship, each eventual official assessment must use `assignment_mode = 'group'`. The first activated official assessment establishes the common official cohort from its persisted `assessment_students` snapshot. If only the official Homework exists, no Blitz Assessment or Blitz recipient rows are fabricated. When the official Blitz is added later, its recipient snapshot must use exactly the established cohort.

## 10.2 `topic_result_pairs` purpose

Change the purpose from only a fully populated pair to:

> Stores the Topic-level official result-bearing pair. The row is created when the official Homework is designated and is completed later when the official Blitz is available.

## 10.3 Column nullability

Required column contract:

```text
homework_assessment_id uuid NOT NULL
blitz_assessment_id    uuid NULL
```

Change the table row to:

```text
| `blitz_assessment_id` | uuid | yes | Nullable until the official Blitz is designated; when present it must be a Blitz in the same Topic |
```

## 10.4 `cohort_snapshotted_at`

Change its note to:

```text
Nullable until the official cohort is established from the first activated
official whole-group task; may be set while blitz_assessment_id is still null
```

## 10.5 `locked_at`

Clarify:

```text
May be set by first relevant official Student Attempt even while
blitz_assessment_id is null
```

## 10.6 Required constraints

The documented persistence constraints must express:

```text
unique(topic_id)

homework_assessment_id:
  required
  same institution/topic
  assessment.type = homework
  assignment_mode = group

blitz_assessment_id:
  nullable
  when non-null:
    same institution/topic
    assessment.type = blitz
    assignment_mode = group
    != homework_assessment_id

locked_at IS NOT NULL
  => cohort_snapshotted_at IS NOT NULL
```

Do **not** add:

```text
blitz_assessment_id IS NOT NULL
```

as a requirement for:

- row existence;
- `cohort_snapshotted_at`;
- `locked_at`.

## 10.7 Foreign key

Keep the FK:

```text
topic_result_pairs.blitz_assessment_id
→ assessments.id
```

but document it as a nullable FK.

## 10.8 Final Topic result

`topic_results` may still require a complete official pair before final calculation.

Do not make final Topic result calculation possible with only Homework.

---

# 11. `docs/09-api-contracts.md`

This document has the mandatory public API alignment.

## 11.1 Stage 6 result-pair GET

Document:

```text
GET /api/v1/teacher/topics/{topic}/result-pair
```

No designation yet:

```json
{
  "data": null
}
```

Existing Stage 6 pair example:

```json
{
  "data": {
    "id": "pair-uuid",
    "topic_id": "topic-uuid",
    "homework_assessment_id": "homework-uuid",
    "blitz_assessment_id": null,
    "cohort_snapshotted_at": null,
    "locked_at": null,
    "designated_at": "2026-09-01T09:00:00Z",
    "created_at": "2026-09-01T09:00:00Z",
    "updated_at": "2026-09-01T09:00:00Z"
  }
}
```

`blitz_assessment_id` remains nullable in read resources.

## 11.2 Stage 6 PUT

For Stage 6, document exact request:

```http
PUT /api/v1/teacher/topics/{topic}/result-pair
Content-Type: application/json
```

```json
{
  "homework_assessment_id": "homework-uuid"
}
```

Do not require or accept a Teacher-supplied Blitz ID in Stage 6.

Remove the current Stage 6 request example:

```json
{
  "homework_assessment_id": "...",
  "blitz_assessment_id": "..."
}
```

as the Stage 6 contract.

Add a forward note:

> Stage 8 extends/completes this Topic-level contract by filling the previously null official Blitz side. It does not replace the locked Homework side.

## 11.3 PUT eligibility

Document:

- authorized same-Topic Teacher;
- Homework candidate is `homework`;
- assignment mode is `group`;
- candidate is eligible draft/active;
- candidate with existing Student activity cannot newly become official;
- selected Homework returns:
  `409 official_task_requires_group_assignment`;
- locked replacement returns:
  `409 result_pair_locked`;
- same-target PUT is idempotent.

## 11.4 Official Homework activation

Replace any Stage 6 effect that says:

```text
activation creates recipient rows for both official assessments
```

with:

> If the designated official Homework is activated before an official Blitz exists, activation snapshots the Homework's eligible whole-group recipients and establishes the official Topic cohort. It does not create a Blitz or Blitz recipient rows. A later official Blitz must reuse that established cohort.

## 11.5 Stage 6 close boundary

The final MVP product contract still requires automatic finalization of
`in_progress` Attempts when Homework is closed.

Add a Stage-boundary note:

> Until Stage 7 exposes public Homework Attempt execution and saved-answer persistence, Stage 6 must not fabricate answer finalization. If a structural `in_progress` Attempt exists in Stage 6 test/fixture state, Homework close returns `409 business_conflict`. Stage 7 replaces this temporary safety guard with the approved atomic auto-finalization behavior before public Attempt start is enabled.

Do not remove the final Stage 7+ `task_closed_auto_finalize` contract.

---

# 12. `docs/01-business-overview.md` and `docs/03-features.md`

Read-only audit.

Do not change general final-product statements such as:

```text
one official Homework + one official Blitz form the final Topic result pair
```

or:

```text
the first official task establishes the common cohort
```

when those statements do not require both tasks to already exist.

Change only if wording explicitly says:

- both must be designated before the first can activate;
- both recipient sets must already exist;
- a result-pair row is invalid with missing Blitz.

If changed, use the same staged wording from Sections 4–11.

---

# 13. No Other Product Changes

This documentation alignment must not change:

- nine Question type definitions;
- Multiple Choice partial-credit rule;
- automatic Short Written normalization;
- fixed Homework three-attempt rule;
- Student submission file limit;
- Homework deadline authority;
- lifecycle values;
- selected-Student practice-only rule;
- final result formula;
- understanding-category rules;
- Blitz timing rules;
- result-release rules.

Do not “clean up” unrelated documentation.

---

# 14. Consistency Search After Editing

After changes, search the affected docs for stale wording.

The following must no longer appear as an active schema/API requirement:

```text
blitz_assessment_id | uuid | no
```

for `topic_result_pairs`.

The following Stage 6 request shape must no longer be the only/current PUT example:

```json
{
  "homework_assessment_id": "...",
  "blitz_assessment_id": "..."
}
```

No documentation may state that Stage 6 Homework activation must create recipient rows for a non-existent Blitz.

Search terms:

```text
blitz_assessment_id
both official assessments
both official tasks
first official task
first official assessment
cohort_snapshotted_at
locked_at
result_pair_locked
official_task_requires_group_assignment
task_closed_auto_finalize
```

Review every hit in `docs/02,04–09`.

---

# 15. Acceptance Criteria

- [ ] `docs/02-user-roles.md` permits staged official-pair construction.
- [ ] `docs/04-user-flows.md` makes Homework-first then Blitz-later flow explicit.
- [ ] `docs/05-business-rules.md` preserves final pair rules while allowing staged construction.
- [ ] `docs/06-roadmap.md` explicitly places Homework-side pair construction in Stage 6 and Blitz completion in Stage 8.
- [ ] `docs/07-architecture.md` defines staged Topic result-pair aggregate.
- [ ] `docs/08-database.md` makes `topic_result_pairs.blitz_assessment_id` nullable.
- [ ] `docs/08-database.md` allows `locked_at != null` while Blitz is null.
- [ ] `docs/08-database.md` does not require fake Blitz recipient rows when Homework activates first.
- [ ] `docs/09-api-contracts.md` Stage 6 PUT accepts only `homework_assessment_id`.
- [ ] `docs/09-api-contracts.md` GET resource permits `blitz_assessment_id: null`.
- [ ] `docs/09-api-contracts.md` activation does not create non-existent Blitz state.
- [ ] `docs/09-api-contracts.md` records the temporary Stage 6 in-progress-close safety boundary without deleting the final Stage 7+ auto-finalization rule.
- [ ] `docs/01`/`03` are reviewed and changed only if explicitly contradictory.
- [ ] No unrelated business rule changes.
- [ ] No production code/test/schema/migration file changes.
- [ ] `git diff --check` passes.
- [ ] final cross-document search finds no active contradictory staged-pair rule.

---

# 16. Allowed Files

Expected changed files:

```text
docs/02-user-roles.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
```

Possible only if actual contradiction is found:

```text
docs/01-business-overview.md
docs/03-features.md
```

Do not change any other file in this task.

---

# 17. Verification

Run:

```bash
git diff --check
git diff --name-only
git diff -- docs/01-business-overview.md \
             docs/02-user-roles.md \
             docs/03-features.md \
             docs/04-user-flows.md \
             docs/05-business-rules.md \
             docs/06-roadmap.md \
             docs/07-architecture.md \
             docs/08-database.md \
             docs/09-api-contracts.md
```

Then run focused text searches for the stale patterns in Section 14.

No backend/frontend tests, suites, builds, Pint, Flutter analyze, or E2E are required because this task is documentation-only.

---

# 18. Delivery

Suggested:

```text
Branch:
docs/s06-contract-alignment

Commit:
docs(stage6): align staged homework result pair

PR base:
main
```

After merge:

```text
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
worktree clean
```

Only then may ChatGPT re-check current `main` and release:

```text
S06-BE-001
```

for Codex implementation.

---

# 19. Final Report

Return:

```text
DOCUMENTATION ALIGNMENT COMPLETE
BLOCKED
```

Include:

1. current baseline SHA;
2. changed docs;
3. exact staged-pair changes;
4. confirmation that `blitz_assessment_id` is documented nullable;
5. confirmation that Stage 6 PUT is Homework-only;
6. confirmation that no fake Blitz/recipient rule remains;
7. Stage 6/Stage 7 close-boundary clarification;
8. `docs/01`/`03` audit result;
9. `git diff --check`;
10. changed-file scope;
11. final Git state;
12. blockers/deviations.

Do not modify production code.
