# Codex Implementation Contract: S06-BE-002 — Typed Question Persistence and Domain Contracts

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-BE-002` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel/PostgreSQL typed Question persistence + reusable authoring-domain validation` |
| Depends on | `S06-BE-001 — Assessment and Homework Persistence Foundation` |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after `S06-BE-001` is `Accepted / Delivered` and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Block checkpoint | Stage 6 Backend Phase 2 after `S06-BE-001…006` are `Accepted / Delivered` |

Do not start implementation until:

- `S06-BE-001` is `Accepted / Delivered`;
- this task remains `Approved`;
- ChatGPT has re-checked current `origin/main` and confirmed that the delivered S06-BE-001 schema/model names match this dependency contract;
- Git preflight is safe.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. the delivered S06-BE-001 source/migrations/models/tests directly required by this task;
5. existing enum/domain/factory/persistence-test patterns directly required for consistent implementation.

Do **not** read product specifications, roadmap files, architecture/database/API documents, previous task files, Stage history, Stage indexes, or closure reviews to determine requirements.

The contract below already resolves:

- all nine Question machine types;
- automatic/manual checking-mode compatibility at authoring time;
- normalized persistence layout;
- same-Institution FK requirements;
- per-type structural configuration;
- authoring limits;
- position rules;
- fill-in-the-blank placeholder semantics;
- fixed file-based extension capability;
- reusable domain-validation boundary;
- explicit exclusions for scoring and HTTP behavior.

If delivered S06-BE-001 materially differs from the dependency assumptions encoded below, return `BLOCKED` with the exact mismatch. Do not silently redesign S06-BE-001 or this task.

---

# 3. Goal

Create the typed Question persistence and reusable authoring-domain contract shared by Homework and future Blitz tasks.

The result must support all nine MVP Question types without storing arbitrary uncontrolled type configuration in a generic JSON/blob column:

1. `single_choice`
2. `multiple_choice`
3. `true_false`
4. `short_written`
5. `open_written`
6. `file_based`
7. `matching`
8. `ordering`
9. `fill_in_blank`

The task must provide:

- one common `questions` table;
- normalized type-specific child tables;
- exact enum/cast/relationship contracts;
- PostgreSQL structural constraints;
- reusable domain validation for type + checking mode + configuration compatibility;
- fixed authoring limits for later Teacher APIs;
- deterministic factories;
- focused persistence/domain tests.

This task must **not** implement Teacher Question HTTP endpoints, Student answer payloads, checking/scoring, or frontend behavior.

---

# 4. Scope

## 4.1 Included

Implement only:

- one or more new forward-only migrations for the Question persistence layer;
- `questions`;
- `question_choice_options`;
- `question_true_false_answers`;
- `question_short_accepted_answers`;
- `question_matching_items`;
- `question_ordering_items`;
- `question_fill_blanks`;
- `question_fill_blank_accepted_answers`;
- required Question enums;
- `QuestionAuthoringLimits`;
- reusable `QuestionConfigurationValidator`;
- reusable `QuestionPositionSetValidator`;
- Eloquent models for the common Question and all normalized child records;
- required `Assessment -> questions` inverse relationship;
- factories for the new models;
- focused PostgreSQL schema/persistence tests;
- focused unit tests for authoring-domain validation.

## 4.2 Shared Homework/Blitz Question layer

The Question layer belongs to a shared Assessment.

It must work structurally for:

```text
Assessment type = homework
Assessment type = blitz
```

S06-BE-002 does not create or manage Blitz lifecycle rows.

No Question schema element may assume that every Assessment is Homework.

## 4.3 Typed persistence principle

Do not add:

```text
questions.configuration json/jsonb
questions.correct_answer json/jsonb
questions.options json/jsonb
```

or another generic free-form persisted blob as the authoritative Question configuration.

The approved model uses explicit normalized child tables.

---

# 5. Explicit Non-Goals

Do not add or change:

- routes;
- controllers;
- Form Requests;
- API Resources;
- public API responses;
- Teacher Homework APIs;
- Teacher Question create/update/delete/reorder APIs;
- nested Homework create API;
- Student Homework APIs;
- Student Attempt APIs;
- Student answer persistence tables;
- answer payload parsing;
- file upload/submission behavior;
- Question checking/scoring strategies;
- awarded-points calculation;
- Homework score normalization;
- official Homework score resolution;
- lifecycle Actions;
- recipient snapshot population;
- official Homework designation;
- Topic result calculation;
- result release;
- Scheduler/deadline runtime;
- seed/demo/E2E data;
- frontend code;
- dependencies;
- `docs/01–09`;
- Stage/task bookkeeping;
- unrelated refactors.

Do not:

- modify S06-BE-001 delivered migration(s) when a new forward migration is appropriate;
- add per-question Blitz timers;
- add negative marking;
- add fuzzy/AI answer matching;
- store Student-facing `max_selections` as an independently mutable database value;
- store file-based maximum upload size per Question;
- create a Question-bank abstraction;
- add reusable curriculum/course-builder infrastructure.

---

# 6. Dependency Contract from S06-BE-001

This task assumes delivered S06-BE-001 provides at least:

```text
assessments
  id uuid PK
  institution_id uuid
  type homework|blitz
  ...

unique(institution_id, id)
```

and model:

```text
App\Models\Assessment
```

with direct Institution ownership.

S06-BE-002 must reference Assessments through same-Institution composite FKs.

If these names or support keys are not present after S06-BE-001 delivery, implementation is blocked pending ChatGPT reconciliation.

---

# 7. Shared Persistence Conventions

Use repository Laravel/PostgreSQL conventions.

Required:

- IDs use PostgreSQL UUIDs;
- authoritative timestamps use `timestamp with time zone`;
- `created_at` and `updated_at` are non-null;
- all new foreign keys use explicit stable names and `ON DELETE RESTRICT`;
- every normalized Question child stores `institution_id` directly;
- each Question child must reference its parent through same-Institution composite FK;
- nested Fill Blank accepted answers must reference a same-Institution Fill Blank;
- structural checks belong in PostgreSQL where practical;
- cross-row/type-specific authoring rules that cannot be safely represented as row-level checks belong in the domain validator;
- do not add PostgreSQL triggers for Question type/checking/configuration rules;
- no hard-delete cascade is allowed from Assessment/Question to educational child rows.

Deleting an Assessment or Question that already owns Question/configuration records must be blocked by restrictive FKs until an explicit future authorized mutation removes safe draft configuration in the correct order.

---

# 8. `questions` Persistence Contract

## 8.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Direct tenant owner |
| `assessment_id` | uuid | no | Same-Institution Assessment |
| `type` | varchar(40) | no | One of the nine exact Question types |
| `prompt` | text | no | Non-empty after `btrim` |
| `instructions` | text | yes | Optional; if non-null must not be whitespace-only |
| `points` | numeric(14,6) | no | Draft may use zero |
| `position` | integer | no | Structural non-negative position |
| `checking_mode` | varchar(20) | no | `automatic|manual` |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Do not add:

```text
time_limit_seconds
configuration
correct_answer
max_selections
negative_points
```

## 8.2 Required support key

```text
unique(institution_id, id)
```

This supports same-Institution child FKs.

## 8.3 Required Question type check

Exactly:

```text
single_choice
multiple_choice
true_false
short_written
open_written
file_based
matching
ordering
fill_in_blank
```

## 8.4 Required checking-mode check

Exactly:

```text
automatic
manual
```

## 8.5 Required common checks

```text
btrim(prompt) <> ''
instructions is null OR btrim(instructions) <> ''
points >= 0
position >= 0
```

`points = 0` is intentionally structurally valid during draft authoring.

The future Homework/Blitz activation Action recalculates all current Question points and requires total possible points to be greater than zero.

Do not put a positive-points activation rule into this table.

## 8.6 Required uniqueness

```text
unique(assessment_id, position)
```

The database prevents two Questions in one Assessment from sharing one persisted position.

Application authoring uses canonical contiguous 1-based positions, defined later in this contract. PostgreSQL intentionally permits non-negative structural positions so migrations/future internal reordering operations are not forced into multi-row transient conflicts outside a transaction.

## 8.7 Required foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, assessment_id)
  -> assessments(institution_id, id)
```

## 8.8 Required index

```text
(institution_id, assessment_id, type)
```

---

# 9. `question_choice_options` Contract

Used only by:

```text
single_choice
multiple_choice
```

Type ownership is enforced by the domain/application layer, not a database trigger.

## 9.1 Columns

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no |
| `institution_id` | uuid | no |
| `question_id` | uuid | no |
| `option_text` | text | no |
| `is_correct` | boolean | no |
| `position` | integer | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

## 9.2 Checks

```text
btrim(option_text) <> ''
position >= 0
```

## 9.3 Uniqueness

```text
unique(question_id, position)
```

Do not persist a separate `max_selections`.

For Multiple Choice:

```text
max_selections = count(current correct options)
```

is derived later.

## 9.4 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, question_id)
  -> questions(institution_id, id)
```

## 9.5 Index

```text
(question_id, is_correct)
```

---

# 10. `question_true_false_answers` Contract

Used only by `true_false`.

## 10.1 Columns

| Column | Type | Null |
|---|---|---:|
| `question_id` | uuid | no |
| `institution_id` | uuid | no |
| `correct_value` | boolean | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

`question_id` is the primary key.

This gives at most one Boolean correct-value row per Question.

## 10.2 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, question_id)
  -> questions(institution_id, id)
```

The domain/application layer requires exactly one row for a valid True/False Question.

---

# 11. `question_short_accepted_answers` Contract

Used only for:

```text
short_written + checking_mode = automatic
```

Manual Short Written Questions must not use accepted-answer rows.

## 11.1 Columns

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no |
| `institution_id` | uuid | no |
| `question_id` | uuid | no |
| `accepted_text` | text | no |
| `position` | integer | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

## 11.2 Checks

```text
btrim(accepted_text) <> ''
position >= 0
```

Do not persist a normalized/case-folded copy in this task.

Automatic Short Written matching later uses the approved runtime normalization pipeline. Authoring stores the Teacher-entered accepted text.

## 11.3 Uniqueness

```text
unique(question_id, position)
```

## 11.4 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, question_id)
  -> questions(institution_id, id)
```

---

# 12. `question_matching_items` Contract

A Matching Question stores explicit left/right items.

The correct relationship is represented by a shared server-generated `match_key` UUID across exactly one left item and one right item in a valid Question configuration.

## 12.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | PK |
| `institution_id` | uuid | no | Tenant |
| `question_id` | uuid | no | Same-Institution Question |
| `side` | varchar(10) | no | `left|right` |
| `match_key` | uuid | no | Correct pair identity |
| `item_text` | text | no | Non-empty |
| `position` | integer | no | Authoring/display order on that side |
| `created_at` | timestamptz | no | |
| `updated_at` | timestamptz | no | |

## 12.2 Checks

```text
side in ('left', 'right')
btrim(item_text) <> ''
position >= 0
```

## 12.3 Required uniqueness

Per side, one persisted display position is unique:

```text
unique(question_id, side, position)
```

A given pair key may have at most one row on each side:

```text
unique(question_id, side, match_key)
```

The domain validator additionally requires every current `match_key` in a valid Matching configuration to have exactly:

```text
1 left
1 right
```

Do not implement that cross-row cardinality through a trigger.

## 12.4 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, question_id)
  -> questions(institution_id, id)
```

## 12.5 Indexes

```text
(question_id, side)
(question_id, match_key)
```

If one of the required unique indexes already fully supports the exact query shape, do not create a redundant duplicate ordinary index solely to satisfy naming. Schema tests should accept the unique index as support only when it actually starts with the same required columns.

---

# 13. `question_ordering_items` Contract

Used only by `ordering`.

## 13.1 Columns

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no |
| `institution_id` | uuid | no |
| `question_id` | uuid | no |
| `item_text` | text | no |
| `correct_position` | integer | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

## 13.2 Checks

```text
btrim(item_text) <> ''
correct_position >= 0
```

## 13.3 Uniqueness

```text
unique(question_id, correct_position)
```

A valid authoring configuration later uses contiguous positions `1..N`.

## 13.4 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, question_id)
  -> questions(institution_id, id)
```

---

# 14. `question_fill_blanks` Contract

Used only by `fill_in_blank`.

## 14.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | PK |
| `institution_id` | uuid | no | Tenant |
| `question_id` | uuid | no | Same-Institution Question |
| `blank_key` | varchar(80) | no | Stable technical placeholder key |
| `position` | integer | no | Authoring order |
| `created_at` | timestamptz | no | |
| `updated_at` | timestamptz | no | |

## 14.2 Required support key

Because accepted-answer rows reference a Fill Blank through same-Institution composite FK:

```text
unique(institution_id, id)
```

## 14.3 Blank-key format

`blank_key` is a machine identifier, not display text.

Require:

```text
^[A-Za-z][A-Za-z0-9_-]{0,79}$
```

Examples:

```text
host
address
ip_address
item-1
```

Reject:

- whitespace;
- braces;
- dots/slashes;
- leading digit;
- empty key;
- values longer than 80 characters.

Use an explicit PostgreSQL CHECK matching the same semantics.

## 14.4 Position check

```text
position >= 0
```

## 14.5 Uniqueness

```text
unique(question_id, blank_key)
unique(question_id, position)
```

## 14.6 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, question_id)
  -> questions(institution_id, id)
```

---

# 15. `question_fill_blank_accepted_answers` Contract

Every configured Fill Blank requires one or more accepted values.

## 15.1 Columns

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no |
| `institution_id` | uuid | no |
| `blank_id` | uuid | no |
| `accepted_text` | text | no |
| `position` | integer | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

## 15.2 Checks

```text
btrim(accepted_text) <> ''
position >= 0
```

Do not persist normalized checking text in this task.

## 15.3 Uniqueness

```text
unique(blank_id, position)
```

## 15.4 Foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, blank_id)
  -> question_fill_blanks(institution_id, id)
```

---

# 16. Question Enum Contract

Follow the existing repository string-backed enum style and expose:

```php
public static function values(): array
```

where used by the current enum convention.

## 16.1 `QuestionType`

Exactly:

```text
SingleChoice = 'single_choice'
MultipleChoice = 'multiple_choice'
TrueFalse = 'true_false'
ShortWritten = 'short_written'
OpenWritten = 'open_written'
FileBased = 'file_based'
Matching = 'matching'
Ordering = 'ordering'
FillInBlank = 'fill_in_blank'
```

## 16.2 `QuestionCheckingMode`

Exactly:

```text
Automatic = 'automatic'
Manual = 'manual'
```

## 16.3 `QuestionMatchingSide`

Exactly:

```text
Left = 'left'
Right = 'right'
```

Reuse the already-existing Stage 5 `FileExtension` enum for:

```text
pdf
docx
ppt
pptx
```

Do not create a second Question-specific file-extension enum.

---

# 17. Fixed Authoring Limits

Create one focused domain constants class:

```text
App\Domain\Assessment\QuestionAuthoringLimits
```

It contains **only** stable Stage 6 authoring safety limits.

Exact limits:

```text
MAX_QUESTIONS_PER_ASSESSMENT = 100

MAX_PROMPT_LENGTH = 10000
MAX_INSTRUCTIONS_LENGTH = 5000

MAX_CHOICE_OPTIONS = 20
MAX_OPTION_TEXT_LENGTH = 2000

MAX_SHORT_ACCEPTED_ANSWERS = 20
MAX_ACCEPTED_ANSWER_LENGTH = 1000

MAX_MATCHING_PAIRS = 50
MAX_MATCHING_ITEM_TEXT_LENGTH = 2000
MAX_CLIENT_KEY_LENGTH = 80

MAX_ORDERING_ITEMS = 50
MAX_ORDERING_ITEM_TEXT_LENGTH = 2000

MAX_FILL_BLANKS = 50
MAX_ACCEPTED_ANSWERS_PER_BLANK = 20
```

These limits are authoritative for later Stage 6 Teacher authoring APIs.

Do not put these values into database CHECK constraints for `text` columns; request/domain validation owns content-length policy. PostgreSQL continues to enforce structural non-empty values and fixed varchar size where defined.

Do not add configurable Institution settings for these limits.

---

# 18. Canonical Application Position Contract

For Teacher-authored API/domain configuration, positions are **1-based and contiguous**.

For a set of `N` current items:

```text
valid positions = 1, 2, ..., N
```

This applies later to:

- Questions within one Assessment;
- Choice options;
- Short accepted answers;
- left Matching items;
- right Matching items;
- Ordering `correct_position`;
- Fill Blank `position`;
- accepted answers within one Fill Blank.

Database checks intentionally allow non-negative integers to support safe transactional reorder mechanics. The application-domain validator is authoritative for the final committed authoring configuration.

Create:

```text
App\Domain\Assessment\QuestionPositionSetValidator
```

with a focused public API equivalent to:

```php
validate(array $positions, int $maximumCount, bool $allowEmpty = false): void
```

Exact behavior:

- every value must be an integer;
- duplicates rejected;
- negative/zero application positions rejected;
- count must not exceed `maximumCount`;
- when `allowEmpty = false`, empty rejected;
- when non-empty, sorted positions must equal exact contiguous `1..N`;
- returns normally on valid input;
- throws `InvalidArgumentException` with a stable non-sensitive developer message on invalid input.

For the complete Assessment Question set, later draft-authoring callers may pass `allowEmpty = true`, because a draft Homework may temporarily have no Questions. Activation will separately require at least one valid Question and positive recalculated total points.

---

# 19. Reusable `QuestionConfigurationValidator`

Create:

```text
App\Domain\Assessment\QuestionConfigurationValidator
```

This is a pure reusable authoring-domain validator.

It must not:

- query the database;
- know HTTP status codes;
- create/update models;
- score Student answers;
- normalize Student answers;
- perform authorization;
- infer Assessment lifecycle.

Recommended public boundary:

```php
validate(
    QuestionType $type,
    QuestionCheckingMode $checkingMode,
    string $prompt,
    array $configuration,
): void
```

Equivalent method naming is allowed if responsibility and inputs remain exact.

Use `QuestionPositionSetValidator` rather than duplicating contiguous-position logic.

On invalid cross-field/type configuration, throw:

```text
InvalidArgumentException
```

with a stable developer-facing message such as:

```text
Invalid question configuration.
```

Do not expose detailed internal validation decisions as a new public API contract here. Later Form Requests/Actions map invalid authoring data to field-level API errors.

The validator must reject unknown configuration keys and unexpected nested keys. It must not silently ignore them.

---

# 20. Common Domain Validation Rules

Before type-specific rules:

## 20.1 Prompt

Require:

```text
string
btrim != ''
mb_strlen <= MAX_PROMPT_LENGTH
```

Do not trim/rewrite the supplied prompt in the domain validator; validate the already-prepared value.

## 20.2 Configuration container

`configuration` must represent exactly the expected key set for the current Question type/mode.

No extra keys.

No protected/future keys.

## 20.3 Checking mode compatibility

Exact allowed matrix:

| Question type | Allowed checking mode |
|---|---|
| `single_choice` | `automatic` only |
| `multiple_choice` | `automatic` only |
| `true_false` | `automatic` only |
| `short_written` | `automatic` or `manual` |
| `open_written` | `manual` only |
| `file_based` | `manual` only |
| `matching` | `automatic` only |
| `ordering` | `automatic` only |
| `fill_in_blank` | `automatic` only |

Do not permit client-selected manual checking for objective types merely because `checking_mode` is a generic column.

Do not permit automatic Open Written or File Based checking in the MVP.

---

# 21. Single Choice Domain Contract

Required configuration shape:

```text
configuration = {
  options: [...]
}
```

Each option contains exactly:

```text
text
is_correct
position
```

Rules:

- option count: `2..MAX_CHOICE_OPTIONS`;
- `text`: non-empty string, max `MAX_OPTION_TEXT_LENGTH`;
- `is_correct`: boolean;
- `position`: application positions exactly contiguous `1..N`;
- exactly **one** option is correct;
- no unknown option/config keys.

Checking mode:

```text
automatic
```

Scoring itself is not implemented in this task.

---

# 22. Multiple Choice Domain Contract

Configuration shape is identical to Single Choice:

```text
configuration = {
  options: [...]
}
```

Rules:

- option count: `2..MAX_CHOICE_OPTIONS`;
- valid non-empty option text;
- boolean `is_correct`;
- contiguous positions `1..N`;
- **one or more** correct options;
- all options being correct is structurally allowed because the locked MVP rule requires one or more correct options, not at least one incorrect distractor;
- no unknown keys.

Checking mode:

```text
automatic
```

Derived later:

```text
max_selections = count(correct options)
```

Do not persist `max_selections`.

---

# 23. True / False Domain Contract

Required configuration:

```text
configuration = {
  correct_value: boolean
}
```

No additional keys.

Checking mode:

```text
automatic
```

The persistence representation is exactly one `question_true_false_answers` row.

---

# 24. Short Written Domain Contract

## 24.1 Automatic Short Written

Checking mode:

```text
automatic
```

Required configuration:

```text
configuration = {
  accepted_answers: [...]
}
```

Rules:

- count `1..MAX_SHORT_ACCEPTED_ANSWERS`;
- each accepted answer is a non-empty string;
- each length <= `MAX_ACCEPTED_ANSWER_LENGTH`;
- list order is stable authoring order;
- exact duplicate strings are rejected;
- no unknown keys.

Do **not** apply the future Student-answer matching normalization to persisted Teacher text at authoring time.

The later checking pipeline remains:

```text
Unicode NFC
trim
collapse internal whitespace
Unicode case-fold comparison
normalize common Uzbek apostrophe variants
preserve other punctuation/technical symbols
exact comparison
```

but implementing that scoring/matching pipeline is outside S06-BE-002.

## 24.2 Manual Short Written

Checking mode:

```text
manual
```

Required configuration:

```text
{}
```

represented to the PHP domain validator as an empty associative array.

Manual Short Written must have **zero** `question_short_accepted_answers` rows in a valid persisted aggregate.

No fuzzy/AI behavior is added.

---

# 25. Open Written Domain Contract

Checking mode:

```text
manual
```

Required configuration:

```text
{}
```

A valid Open Written Question has none of the type-specific configuration rows from:

- choice options;
- true/false answer;
- short accepted answers;
- matching items;
- ordering items;
- fill blanks.

No automatic answer key exists.

---

# 26. File Based Domain Contract

Checking mode:

```text
manual
```

Teacher may not customize supported file extensions in the MVP.

The fixed supported extension set is exactly the existing Stage 5 file-extension set:

```text
pdf
docx
ppt
pptx
```

The canonical API-facing configuration later is:

```text
configuration = {
  allowed_extensions: [
    "pdf",
    "docx",
    "ppt",
    "pptx"
  ]
}
```

For this domain validator:

- require exactly the `allowed_extensions` key;
- require exactly those four unique strings;
- require canonical order `pdf, docx, ppt, pptx`;
- reject missing, additional, removed, reordered, duplicated, or unsupported extensions;
- reject any per-Question size field.

No type-specific database child row is required for File Based Questions because the extension capability is fixed platform policy, not Teacher-owned persistent configuration.

The future effective Student submission size is Institution/platform policy and is not persisted per Question.

---

# 27. Matching Domain Contract

Checking mode:

```text
automatic
```

Authoring configuration:

```text
configuration = {
  pairs: [
    {
      client_key: "...",
      left: "...",
      right: "..."
    }
  ]
}
```

Each pair has exactly:

```text
client_key
left
right
```

Rules:

- pair count `1..MAX_MATCHING_PAIRS`;
- `client_key` is a non-empty string, max `MAX_CLIENT_KEY_LENGTH`;
- `client_key` values are unique within the Question;
- `left` and `right` are non-empty strings;
- each side text length <= `MAX_MATCHING_ITEM_TEXT_LENGTH`;
- no unknown keys.

`client_key` is an authoring correlation key only.

It is **not** persisted as the correct-answer authority.

When a later persistence Action creates rows, it generates one server UUID `match_key` per pair and stores that same UUID on exactly:

```text
one left item
one right item
```

The persistent left/right `position` values use `1..N` according to authoring pair order.

A valid persisted Matching configuration must have:

- at least one pair;
- equal left/right counts;
- every `match_key` appearing exactly twice:
  - once on `left`;
  - once on `right`;
- no unrelated configuration rows.

The domain/application layer owns the “exactly one left + one right” cross-row rule.

---

# 28. Ordering Domain Contract

Checking mode:

```text
automatic
```

Configuration:

```text
configuration = {
  items: [
    {
      text: "...",
      correct_position: 1
    }
  ]
}
```

Each item has exactly:

```text
text
correct_position
```

Rules:

- item count `2..MAX_ORDERING_ITEMS`;
- text non-empty;
- text length <= `MAX_ORDERING_ITEM_TEXT_LENGTH`;
- `correct_position` integer;
- correct positions must be exact contiguous `1..N`;
- no unknown keys.

The list order in the authoring request does not create a second correct-order authority. `correct_position` is authoritative for persisted correct order.

---

# 29. Fill-in-the-Blank Domain Contract

Checking mode:

```text
automatic
```

Configuration:

```text
configuration = {
  blanks: [
    {
      key: "host",
      position: 1,
      accepted_answers: [...]
    }
  ]
}
```

Each blank contains exactly:

```text
key
position
accepted_answers
```

Rules:

- blank count `1..MAX_FILL_BLANKS`;
- `key` matches:
  `^[A-Za-z][A-Za-z0-9_-]{0,79}$`;
- keys unique within the Question;
- blank `position` values exact contiguous `1..N`;
- `accepted_answers` count `1..MAX_ACCEPTED_ANSWERS_PER_BLANK`;
- every accepted answer non-empty;
- each accepted answer length <= `MAX_ACCEPTED_ANSWER_LENGTH`;
- exact duplicate accepted strings within one blank rejected;
- no unknown keys.

## 29.1 Placeholder contract

The Question prompt embeds blanks using exactly:

```text
{{blank_key}}
```

Example:

```text
DNS converts {{host}} into an {{address}}.
```

The validator must parse valid placeholders matching:

```text
{{[A-Za-z][A-Za-z0-9_-]{0,79}}}
```

and require:

- every configured `key` appears in the prompt exactly once;
- every valid placeholder found in the prompt has a configured blank;
- no configured blank is absent from the prompt;
- duplicate occurrence of the same configured placeholder is invalid.

The validator does not rewrite the prompt.

Literal braces that do not match the valid placeholder grammar are ordinary prompt text and do not create a blank.

This rule makes Student rendering deterministic without requiring HTML parsing or free-form markup interpretation.

---

# 30. Persisted Aggregate Type-Exclusivity Contract

PostgreSQL child tables cannot safely express all type-to-child cardinality rules without triggers.

Do not add triggers.

Later create/update Actions must persist a Question such that its current typed child graph is exactly compatible with its type/mode.

The domain contract is:

| Type/mode | Required typed rows | Forbidden typed rows |
|---|---|---|
| Single Choice / automatic | `>=2 choice_options`, exactly one correct | all non-choice config |
| Multiple Choice / automatic | `>=2 choice_options`, >=1 correct | all non-choice config |
| True/False / automatic | exactly one true-false row | all other config |
| Short Written / automatic | `>=1 short_accepted_answers` | all other config |
| Short Written / manual | none | all typed config |
| Open Written / manual | none | all typed config |
| File Based / manual | none | all typed config |
| Matching / automatic | valid left/right matching rows | all other config |
| Ordering / automatic | `>=2 ordering_items` | all other config |
| Fill-in-Blank / automatic | blanks + >=1 accepted answer per blank | all other config |

S06-BE-002 must encode these rules in tests/domain validation sufficiently that S06-BE-003/004 can reuse them rather than inventing alternate behavior.

Do not add a persistence method that silently deletes incompatible rows merely when validation fails. Future mutation Actions own transactional replacement/removal of old draft configuration.

---

# 31. Eloquent Model Contract

Create:

```text
App\Models\Question
App\Models\QuestionChoiceOption
App\Models\QuestionTrueFalseAnswer
App\Models\QuestionShortAcceptedAnswer
App\Models\QuestionMatchingItem
App\Models\QuestionOrderingItem
App\Models\QuestionFillBlank
App\Models\QuestionFillBlankAcceptedAnswer
```

Models must contain representation/relationships/casts only.

No model may:

- authorize;
- calculate Student scores;
- normalize Student answers;
- decide lifecycle;
- automatically create/delete sibling configuration;
- call HTTP/storage code.

## 31.1 `Question`

Required casts:

```text
type -> QuestionType
checking_mode -> QuestionCheckingMode
points -> precise decimal cast consistent with repository numeric usage
position -> integer
```

Required relationships:

```text
institution
assessment
choiceOptions
trueFalseAnswer
shortAcceptedAnswers
matchingItems
orderingItems
fillBlanks
```

## 31.2 Choice Option

Casts:

```text
is_correct -> boolean
position -> integer
```

Relationships:

```text
institution
question
```

## 31.3 True/False Answer

Casts:

```text
correct_value -> boolean
```

Relationships:

```text
institution
question
```

Configure `question_id` correctly as its non-incrementing UUID primary key.

## 31.4 Short Accepted Answer

Cast:

```text
position -> integer
```

Relationships:

```text
institution
question
```

## 31.5 Matching Item

Casts:

```text
side -> QuestionMatchingSide
position -> integer
```

Relationships:

```text
institution
question
```

`match_key` remains a UUID string/value; do not invent an Eloquent relation for it.

## 31.6 Ordering Item

Cast:

```text
correct_position -> integer
```

Relationships:

```text
institution
question
```

## 31.7 Fill Blank

Cast:

```text
position -> integer
```

Relationships:

```text
institution
question
acceptedAnswers
```

## 31.8 Fill Blank Accepted Answer

Cast:

```text
position -> integer
```

Relationships:

```text
institution
blank
```

---

# 32. Required Change to `Assessment`

Modify only the delivered S06-BE-001 `App\Models\Assessment` to add:

```text
questions
```

as a `HasMany` relationship.

Do not alter:

- Assessment writable fields;
- existing enum casts;
- tenant behavior;
- Homework relationships;
- recipient/attempt/result-pair relationships from S06-BE-001.

No existing Stage 5 model needs modification in this task.

---

# 33. Factory Contract

Create factories for all new models.

Factories are test infrastructure and must produce same-Institution graphs.

Do not build Question mutation/scoring workflows into factories.

## 33.1 `QuestionFactory`

Default may be:

```text
type = single_choice
checking_mode = automatic
points = 1
position = 1
```

with valid common prompt/instructions.

The default Question row itself need not automatically create type-specific child rows.

Provide explicit type/mode states:

```text
singleChoice()
multipleChoice()
trueFalse()
shortWrittenAutomatic()
shortWrittenManual()
openWritten()
fileBased()
matching()
ordering()
fillInBlank()
```

Each state changes only common Question type/checking metadata.

Child configuration is created explicitly by child factories/tests.

## 33.2 Child factories

Create focused factories for:

```text
QuestionChoiceOption
QuestionTrueFalseAnswer
QuestionShortAcceptedAnswer
QuestionMatchingItem
QuestionOrderingItem
QuestionFillBlank
QuestionFillBlankAcceptedAnswer
```

Each default graph must:

- create/use a same-Institution parent;
- preserve parent Institution;
- generate structurally valid row values;
- not silently create an entire assessment workflow.

For Fill Blank accepted answer, `institution_id` must match the Fill Blank.

For Matching items, provide readable `left()` / `right()` states if useful.

---

# 34. Authorization and Tenant-Isolation Boundary

There is no public actor-driven endpoint in S06-BE-002.

Therefore:

```text
HTTP authorization = N/A
```

Structural tenant isolation is mandatory.

Database tests must prove rejection of child records where:

- Question Institution differs from Assessment Institution;
- choice/true-false/short/matching/ordering/fill parent Question belongs to another Institution;
- Fill Blank accepted answer Institution differs from Fill Blank Institution.

Do not add role/current-membership checks to database triggers.

Later Teacher APIs still derive trusted Institution scope from authenticated Teacher and resolve Assessment/Question inside authorized Topic scope.

S06-BE-002 must not weaken any S06-BE-001 or Stage 5 tenant support key.

---

# 35. Validation and Error Boundary

No HTTP validation/error envelope is implemented in this task.

Two different boundaries exist:

## 35.1 PostgreSQL structural rejection

Invalid row-level data/FK/unique violations must be rejected by the database.

## 35.2 Domain authoring rejection

Invalid cross-field/type configuration passed to:

```text
QuestionConfigurationValidator
QuestionPositionSetValidator
```

must throw `InvalidArgumentException`.

Do not create API exceptions or map them to `422` yet.

Later S06-BE-003/004 Form Requests/Actions own exact public field-error mapping.

---

# 36. Concurrency and Idempotency

## Database concurrency

This task relies on database uniqueness/FKs for:

- unique Question position per Assessment;
- unique option position;
- unique matching side position/pair-side key;
- unique ordering correct position;
- unique Fill Blank key/position;
- unique accepted-answer position.

Do not implement row-locking Actions.

Question add/update/delete/reorder concurrency belongs to S06-BE-004.

## API idempotency

```text
N/A — no API mutation is implemented.
```

## Domain validators

Must be pure/stateless and deterministic.

No global mutable cache.

No current time dependency.

---

# 37. Architecture and Placement

Use:

```text
backend/app/Enums
backend/app/Domain/Assessment
backend/app/Models
backend/database/migrations
backend/database/factories
backend/tests/Feature/Persistence
backend/tests/Unit/Domain/Assessment
```

Required domain classes:

```text
App\Domain\Assessment\QuestionAuthoringLimits
App\Domain\Assessment\QuestionPositionSetValidator
App\Domain\Assessment\QuestionConfigurationValidator
```

Do not introduce:

- `QuestionManager`;
- generic rule engine;
- abstract factory hierarchy;
- plugin architecture;
- JSON schema framework;
- Strategy classes for scoring/checking in this task.

The future scoring architecture may use Question checkers in Stage 9. Do not pre-implement them.

The purpose of S06-BE-002 domain code is **authoring validity**, not Student-answer evaluation.

---

# 38. Expected Files and Areas

Exact migration timestamp/name is an ordinary local choice as long as it is one focused forward-only Stage 6 migration or a minimal logically ordered set.

| Path or area | Action | Reason |
|---|---|---|
| `backend/database/migrations/*create_question*persistence*.php` or equivalent | Create | Common + normalized typed tables |
| `backend/app/Enums/QuestionType.php` | Create | Nine machine types |
| `backend/app/Enums/QuestionCheckingMode.php` | Create | Automatic/manual |
| `backend/app/Enums/QuestionMatchingSide.php` | Create | Left/right matching rows |
| `backend/app/Domain/Assessment/QuestionAuthoringLimits.php` | Create | Fixed safety limits |
| `backend/app/Domain/Assessment/QuestionPositionSetValidator.php` | Create | Canonical contiguous position rule |
| `backend/app/Domain/Assessment/QuestionConfigurationValidator.php` | Create | Reusable type/mode/config validator |
| `backend/app/Models/Question.php` | Create | Common Question model |
| `backend/app/Models/QuestionChoiceOption.php` | Create | Choice options |
| `backend/app/Models/QuestionTrueFalseAnswer.php` | Create | Boolean correct value |
| `backend/app/Models/QuestionShortAcceptedAnswer.php` | Create | Automatic Short Written values |
| `backend/app/Models/QuestionMatchingItem.php` | Create | Matching items |
| `backend/app/Models/QuestionOrderingItem.php` | Create | Ordering items |
| `backend/app/Models/QuestionFillBlank.php` | Create | Fill Blank metadata |
| `backend/app/Models/QuestionFillBlankAcceptedAnswer.php` | Create | Blank accepted values |
| `backend/app/Models/Assessment.php` | Modify | `questions` inverse only |
| `backend/database/factories/QuestionFactory.php` | Create | Common Question factory |
| `backend/database/factories/QuestionChoiceOptionFactory.php` | Create | Choice test infrastructure |
| `backend/database/factories/QuestionTrueFalseAnswerFactory.php` | Create | True/False test infrastructure |
| `backend/database/factories/QuestionShortAcceptedAnswerFactory.php` | Create | Short-answer test infrastructure |
| `backend/database/factories/QuestionMatchingItemFactory.php` | Create | Matching test infrastructure |
| `backend/database/factories/QuestionOrderingItemFactory.php` | Create | Ordering test infrastructure |
| `backend/database/factories/QuestionFillBlankFactory.php` | Create | Fill Blank test infrastructure |
| `backend/database/factories/QuestionFillBlankAcceptedAnswerFactory.php` | Create | Blank-answer test infrastructure |
| `backend/tests/Feature/Persistence/QuestionSchemaInspectionTest.php` | Create | Exact PostgreSQL shape |
| `backend/tests/Feature/Persistence/QuestionPersistenceTest.php` | Create | DB invariants/tenant FKs |
| `backend/tests/Feature/Persistence/QuestionFactoryModelTest.php` | Create | Model/cast/factory graph |
| `backend/tests/Unit/Domain/Assessment/QuestionConfigurationValidatorTest.php` | Create | All nine domain configurations |
| `backend/tests/Unit/Domain/Assessment/QuestionPositionSetValidatorTest.php` | Create | Canonical positions/limits |

Changes outside these areas require a concrete task necessity and must be reported.

Do not modify routes, controllers, Requests, Resources, Actions, seeders, docs, task files, frontend, dependencies, or unrelated tests.

---

# 39. Acceptance Criteria

The implementation is complete only when all are true.

- [ ] `questions` exists with exact nine-type/checking/common structural contract.
- [ ] No generic authoritative JSON/JSONB Question configuration column exists.
- [ ] All seven normalized child configuration tables exist with required same-Institution FKs.
- [ ] All new foreign keys are restrictive and prevent cross-Institution attachment.
- [ ] Question/child text structural rows reject blank-only values where specified.
- [ ] Required position/uniqueness checks and indexes exist.
- [ ] Fill Blank keys enforce the exact machine-key grammar.
- [ ] Matching rows structurally prevent duplicate same-side position and duplicate same-side `match_key`.
- [ ] `QuestionType`, `QuestionCheckingMode`, and `QuestionMatchingSide` expose exact machine values.
- [ ] Existing `FileExtension` is reused; no duplicate extension enum is introduced.
- [ ] Fixed `QuestionAuthoringLimits` contain exactly the approved limits in this task.
- [ ] `QuestionPositionSetValidator` enforces maximum count and canonical contiguous 1-based positions.
- [ ] `QuestionConfigurationValidator` is pure, query-free, deterministic, and rejects unknown keys.
- [ ] Single Choice requires >=2 options and exactly one correct.
- [ ] Multiple Choice requires >=2 options and >=1 correct; `max_selections` is not persisted.
- [ ] True/False requires automatic mode and Boolean correct value.
- [ ] Automatic Short Written requires accepted answers; manual Short Written has empty configuration.
- [ ] Open Written is manual with no answer-key config.
- [ ] File Based is manual with exactly fixed PDF/DOCX/PPT/PPTX capability and no per-Question size configuration.
- [ ] Matching requires valid pair definitions and server-generated persistent `match_key` semantics are encoded for later Actions.
- [ ] Ordering requires at least two items and contiguous correct positions.
- [ ] Fill-in-the-Blank requires configured blanks, accepted answers, unique keys, and exact one-to-one prompt placeholder coverage.
- [ ] Type/checking-mode matrix is exact.
- [ ] Models contain casts/relationships only, no workflow/scoring/authorization.
- [ ] `Assessment` changes only by adding `questions`.
- [ ] Factories create structurally valid same-Institution records.
- [ ] No Teacher/Student HTTP API, Question mutation Action, scoring/checking, Student answers, Blitz runtime, frontend, docs, seeders, dependency changes, or unrelated refactor enters scope.
- [ ] New focused persistence/domain tests pass.
- [ ] S06-BE-001 focused persistence regression passes.
- [ ] Pint passes.
- [ ] `git diff --check` passes.
- [ ] Final focused diff review finds no P1/P2 security, tenant, data-integrity, architecture, or scope issue.

---

# 40. Focused Tests and Verification

Run from:

```text
backend/
```

Do **not** run the full backend suite. Full regression belongs to Stage 6 Backend Phase 2.

## 40.1 New persistence tests

```bash
php artisan test \
  tests/Feature/Persistence/QuestionSchemaInspectionTest.php \
  tests/Feature/Persistence/QuestionPersistenceTest.php \
  tests/Feature/Persistence/QuestionFactoryModelTest.php
```

Required cases include:

### Schema

- exact tables/columns/types/nullability;
- nine Question type CHECK values;
- checking-mode values;
- prompt/instructions/points/position row checks;
- support unique `(institution_id, id)` on `questions`;
- unique Question position per Assessment;
- same-Institution composite FKs;
- all FKs `ON DELETE RESTRICT`;
- choice uniqueness/index;
- True/False PK;
- short accepted-answer position uniqueness;
- matching side/position/pair-key structural uniqueness;
- ordering position uniqueness;
- Fill Blank key regex + uniqueness + support key;
- Fill Blank accepted-answer position uniqueness;
- no generic Question JSON/JSONB configuration/correct-answer column;
- no answer/submission/scoring table added by this task.

### Persistence

- valid Question for same-Institution Assessment persists;
- foreign-Institution Assessment reference rejected;
- invalid Question type/checking mode rejected;
- blank prompt / blank non-null instructions rejected;
- negative points/position rejected;
- duplicate Assessment Question position rejected;
- each child rejects cross-Institution Question/Blank parent;
- child blank text/negative position rejects where required;
- choice duplicate position rejected;
- matching duplicate side-position and side-match-key rejected;
- ordering duplicate correct position rejected;
- invalid Fill Blank key rejected;
- duplicate Fill Blank key/position rejected;
- restrictive deletion protects referenced configuration/history.

## 40.2 Domain unit tests

```bash
php artisan test \
  tests/Unit/Domain/Assessment/QuestionConfigurationValidatorTest.php \
  tests/Unit/Domain/Assessment/QuestionPositionSetValidatorTest.php
```

Cover at least:

### Position validator

- valid `1..N`;
- one item;
- allowed empty when explicitly requested;
- empty rejected by default;
- zero rejected;
- negative rejected;
- duplicate rejected;
- gap rejected;
- non-integer rejected;
- over maximum rejected.

### Question configuration validator

Positive coverage for all nine types/modes.

Negative coverage:

- wrong checking mode for every fixed-mode type;
- unknown top-level configuration key;
- unknown nested key;
- option count under/over limit;
- Single Choice zero/multiple correct;
- Multiple Choice zero correct;
- invalid/non-contiguous option position;
- Short Written auto without accepted answer;
- Short Written manual with accepted answer config;
- duplicate automatic Short Written accepted string;
- Open Written with config;
- File Based missing/extra/reordered/customized extension set;
- File Based size configuration attempt;
- Matching no pairs/over limit/duplicate client key/blank side;
- Ordering fewer than 2/over limit/duplicate/gapped positions;
- Fill Blank invalid key;
- Fill Blank missing accepted answer;
- duplicate blank key;
- duplicate/gapped blank position;
- configured blank missing from prompt;
- prompt placeholder without configured blank;
- same blank placeholder appearing twice;
- over authoring text/list limits.

## 40.3 Directly affected S06-BE-001 regression

After S06-BE-001 is delivered, run its exact focused persistence tests:

```bash
php artisan test \
  tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php \
  tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php \
  tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php
```

Reason:

- this task references `assessments`;
- modifies `Assessment` with a new inverse relationship;
- must prove S06-BE-001 persistence/casts/factory behavior remains intact.

No Stage 5 full or broad regression is required at this task level unless implementation necessarily changes a shared Stage 5 parent/schema outside this contract. If that happens, report the exact regression risk rather than silently expanding verification.

## 40.4 Format

```bash
./vendor/bin/pint --test
```

## 40.5 Always

```bash
git diff --check
```

Then inspect the complete diff:

- only required migration/enums/domain/models/factories/tests changed;
- S06-BE-001 delivered migration not rewritten;
- no API/route/controller/action appeared;
- no Student answer/scoring code appeared;
- no generic JSON Question configuration was introduced;
- no unrelated model relationship changed;
- no tenant FK weakened;
- no test weakened;
- no debug code, secrets, temporary/generated junk, or formatting churn;
- user work preserved.

Narrow diagnostic reruns are allowed only to investigate a concrete failure.

## 40.6 Project Owner manual check

```text
Not required — backend persistence/domain-only task with no public/API/UI behavior.
```

---

# 41. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested delivery:

```text
Branch: feat/s06-be-002-typed-question-foundation
Commit: feat(stage6): add typed question foundation
PR base: main
```

The delivery must contain only task-owned backend source/tests.

Codex must not:

- commit;
- push;
- open/merge PR;
- change this task file;
- change Stage index/bookkeeping.

Codex stops after implementation, focused verification, `git diff --check`, and focused diff/scope review.

Task acceptance occurs only after approved delivery completes, result is on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

---

# 42. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to discover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Stage 6 approved decomposition | S06-BE-002 owns normalized typed Question persistence and reusable authoring-domain rules |
| `docs/05-business-rules.md` Question rules | Nine types; fixed objective/manual mode semantics; required correct-answer structures |
| `docs/06-roadmap.md` Stage 6 | Builder must support every MVP Question type; activation later requires valid positive scoreable total |
| `docs/07-architecture.md` Question architecture | Explicit typed structures; no uncontrolled blob; scoring strategies belong later |
| `docs/08-database.md` Questions/type-specific tables | Normalized table layout, direct Institution ownership, numeric position/points structure |
| `docs/09-api-contracts.md` Question authoring examples | Type-specific configuration shapes and fixed file-extension capability |
| Approved Stage 6 planning resolution | Authoring counts/text limits fixed in this contract before implementation |
| Approved Stage 6 planning resolution | Application authoring positions are canonical contiguous 1-based; DB remains structurally non-negative |
| Approved Stage 6 planning resolution | Fill Blank placeholder syntax is `{{blank_key}}` with exact configured-placeholder correspondence |
| Current repository Domain pattern | Focused stateless validator using `InvalidArgumentException`, no generic rule framework |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 43. Codex Final Report

Return one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

`DELIVERY BLOCKED` is not applicable because delivery is Project Owner-owned.

Return:

1. **Status**.
2. **Implementation** — concise result.
3. **Changed files** — file → purpose.
4. **Acceptance criteria** — concise implementation-owned evidence.
5. **Focused verification** — exact commands/results.
6. **Question-domain validation** — concise all-nine-type evidence.
7. **Persistence/tenant integrity** — concise evidence.
8. **Scope/diff** — non-goals, `git diff --check`, no unrelated changes.
9. **Delivery handoff** — Project Owner + current Git state.
10. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not paste large successful logs or repeat this contract.

If a required product, schema, security, tenant, lifecycle, validation, concurrency, or architecture decision appears missing or conflicts with delivered S06-BE-001/current source, return `BLOCKED` rather than deciding independently.
