# TestLabUz Backend Engineering Rules

## 1. Scope

This file applies automatically to implementation work that changes files under `backend/`.

Read it together with the root `AGENTS.md`.

The approved implementation contract defines the required behavior, API, schema, validation, authorization, lifecycle, concurrency, tests, and verification commands. This file defines the Laravel/PostgreSQL engineering standard for implementing that contract.

The root `AGENTS.md` remains authoritative for general engineering, security, verification, context-discipline, Git, and repository-safety rules. This file adds backend-specific rules and must not be used to infer missing product behavior.

If the approved implementation contract is materially incomplete or conflicts with this file or the current backend implementation, report the exact blocker instead of making a product, API, database, security, or lifecycle decision.

## 2. Backend Architecture

Use the existing Laravel modular-monolith structure and established repository conventions.

Prefer the responsibility flow:

```text
HTTP boundary
  -> focused Application/Action use case
  -> Domain rule/service when reusable stateful logic is needed
  -> Eloquent / database / infrastructure
```

Create only the classes and directories needed for the current approved implementation contract.

Do not introduce a new architectural style, package, framework, repository layer, command bus, event system, or generic service framework unless the approved implementation contract explicitly requires it.

## 3. HTTP Boundary

Controllers must remain thin.

A controller should normally:

1. receive an already validated request;
2. resolve the authenticated actor/context;
3. call one focused Action/use case;
4. return an existing Resource/response type.

Do not place complex tenant scoping, authorization, lifecycle decisions, transactions, row locking, or multi-step persistence directly in controllers.

Use method/constructor injection and existing Laravel dependency resolution. Do not use a service locator as a shortcut.

Routes must use the existing versioning, middleware, naming, and ordering conventions. Do not add aliases or duplicate route families unless the approved implementation contract requires them.

## 4. Request Validation

Use Form Requests for request-shape rules such as:

- accepted body/query keys;
- required/optional fields;
- types and formats;
- enum membership;
- UUID syntax;
- simple length/range constraints;
- body/query prohibition.

Reject unknown or protected input when the approved implementation contract requires a strict input shape.

Keep normalization explicit and contract-aligned. Do not silently rewrite values beyond the approved contract.

Form Requests must not become a hidden domain-service layer. Rules that depend on persisted records, actor scope, lifecycle, concurrency, or cross-record state belong in focused Actions/domain logic.

## 5. Actions and Domain Logic

Each Action/service must represent one clear use case or cohesive reusable rule.

Prefer focused responsibilities over broad classes such as:

```text
GeneralService
InstitutionManager
CommonRepository
DatabaseHelper
```

Do not duplicate one authoritative rule across Controllers, Form Requests, Models, Resources, and tests.

Use a Domain service/value object only when it provides a real reusable boundary. Do not create abstractions mechanically for simple contract-local behavior.

Eloquent Models may own relationships, casts, focused query scopes, and model-level representation concerns. They should not become catch-all workflow managers.

## 6. Authorization and Tenant Isolation

Start institution-owned access from trusted authenticated context.

Required query concept:

```text
authenticated scope
  -> tenant-scoped query
  -> role/relationship/lifecycle rule
  -> read or mutation
```

Avoid:

```text
Model::find($id)
  -> then decide whether the actor may see it
```

when a scoped query can prevent existence disclosure.

A valid UUID is not authorization.

Apply tenant scope before:

- search;
- filtering;
- sorting;
- pagination;
- aggregates;
- eager loading;
- mutation;
- relationship resolution.

Cross-tenant reads, writes, joins, and relationships must remain impossible through direct IDs, nested resources, filters, or route-model binding.

Route-model binding must not resolve an institution-owned record outside the trusted authenticated scope and then rely on a later authorization check when a scope-safe resolution strategy is available.

Use the contract-defined privacy-safe not-found/forbidden behavior. Do not leak whether an inaccessible record exists.

Do not accept a client-supplied ownership field as authority.

## 7. Eloquent and Query Quality

Keep tenant scoping explicit and reviewable.

Select only the fields needed by the use case.

Avoid:

- N+1 queries;
- unnecessary large eager-loaded graphs;
- loading all rows and filtering/sorting/paginating in PHP;
- unbounded collection reads for list endpoints;
- generic “without scope” helpers in normal feature code;
- hidden queries inside Resources that cause N+1 behavior.

Use server-side filtering, sorting, pagination, and aggregates.

Use deterministic ordering for paginated results when required by the approved implementation contract.

Add or use indexes that support the approved query shape. Performance changes must never weaken tenant safety or correctness.

Do not create repository interfaces around every Eloquent Model. Introduce a query/repository abstraction only when it provides a genuine reusable persistence boundary.

## 8. Persistence and Migrations

Use migrations for every schema change.

Follow the repository's existing UUID, timestamp, foreign-key, naming, and index conventions unless the approved implementation contract explicitly defines a different contract.

Structural invariants belong in the database when practical:

- foreign keys;
- uniqueness;
- check constraints;
- non-null constraints;
- indexes.

Application validation remains required when the rule depends on actor/context/state.

Migration rules:

- preserve existing data;
- do not silently drop, rename, reinterpret, or destructively rewrite existing columns/tables;
- do not edit already-delivered migrations when a new forward migration is appropriate;
- make rollback safe where practical;
- account for existing rows before adding `NOT NULL`, uniqueness, or new constraints;
- use PostgreSQL-compatible SQL and behavior;
- do not substitute SQLite assumptions for PostgreSQL-specific behavior;
- do not add PostgreSQL RLS unless explicitly required.

Do not manually mutate a shared/production schema as normal workflow.

Do not place secrets or environment-specific values in migrations.

## 9. Mass Assignment, Casting, and Serialization

Keep writable attributes explicit.

Do not allow request payloads to mass-assign ownership, creator, lifecycle, security, or protected technical fields.

Use casts/enums/value objects according to existing project conventions for stable machine values and timestamps.

Do not expose internal columns through default model serialization.

Public API fields must be selected intentionally through Resources or the existing response boundary.

Resources serialize already-resolved application state; they must not contain business decisions, authorization, persistence writes, or hidden query orchestration.

## 10. Transactions and Concurrency

Use a database transaction when one logical operation:

- performs multiple dependent writes;
- changes lifecycle state;
- requires a consistent read-modify-write decision;
- must prevent partial persistent state.

Use row locks, uniqueness constraints, idempotency/state guards, or compare-and-set behavior only when the approved implementation contract identifies a concrete race or invariant.

When row locking is required:

- acquire it inside a transaction;
- scope the target to the authenticated tenant before locking;
- reload fresh state under the lock;
- make the final decision from locked current state.

Do not use locks as a substitute for database constraints.

Do not add unnecessary locking to simple operations without a real consistency requirement.

Expected conflicts must map through the existing application/API error boundary rather than leaking database exceptions.

## 11. Error Handling and API Responses

Use the existing exception, validation, error-envelope, Resource, and pagination conventions.

Known failures should use specific exceptions/result types or established framework behavior.

Do not:

- throw generic exceptions for expected conditions;
- branch on human-readable messages;
- expose stack traces, SQL, table/column details, internal class names, tokens, or secrets;
- return inconsistent endpoint-specific envelope shapes;
- catch and discard unexpected programming errors.

Database constraint violations that can occur concurrently must be converted into the contract-defined safe response without leaking database details.

Keep HTTP status, machine code, message, and error fields aligned with the approved implementation contract.

## 12. Configuration and Infrastructure

Use `config()` in application code.

Use `env()` only in configuration files unless an existing project convention explicitly requires otherwise.

Do not hardcode deployment-specific URLs, credentials, storage paths, ports, or environment values.

Reuse existing filesystem, queue, cache, clock/time, authentication, and API infrastructure.

Do not introduce an external service or infrastructure dependency unless explicitly required by the approved implementation contract.

## 13. Logging and Sensitive Data

Logs must be useful but minimal.

Safe operational metadata may include identifiers and action/error categories only when appropriate.

Do not log:

- passwords;
- bearer/plain-text tokens;
- credentials or secrets;
- private keys;
- raw sensitive request/response bodies;
- SQL containing private values;
- full private student/user content by default.

Do not add debug logging that remains in production code.

## 14. Backend Tests

Use focused PHPUnit/Laravel tests matching the approved implementation contract.

Feature tests should verify the real HTTP/middleware/validation/action/persistence/Resource boundary when the approved implementation contract exposes an API.

Add unit/domain tests only when there is isolated reusable logic worth testing separately.

For new or changed institution-owned behavior, include cross-tenant negative coverage when that tenant boundary is part of the changed responsibility. Existing coverage may be reused only when it directly exercises the same authorization/scoping boundary and the approved implementation contract permits that verification scope.

Test relevant:

- happy path;
- strict validation/input shape;
- authentication/authorization;
- tenant isolation and existence privacy;
- lifecycle/state conflicts;
- database constraints;
- transaction rollback;
- concurrency/idempotency when specified;
- no-op/timestamp behavior when specified;
- response status/envelope/resource shape.

Keep tests deterministic:

- use the configured test database;
- use time-travel/frozen clock helpers instead of sleeps;
- do not call real external networks;
- do not hide database behavior behind mocks when persistence is the subject of the test.

Do not weaken existing tests to accommodate incorrect implementation.

## 15. Backend Verification Boundary

Per-task verification is governed by the approved implementation contract and the root `AGENTS.md`.

Backend engineering rules do not independently expand verification into the full backend suite. Full backend regression is a Stage checkpoint activity unless the approved implementation contract explicitly requires broader verification for a concrete regression risk.

Narrow diagnostic test runs or reruns are allowed when needed to understand a failure.

## 16. Backend Diff Review

In addition to the root diff review, verify:

- Controllers are thin;
- request validation and stateful rules are separated;
- tenant scope precedes record exposure;
- Models/Resources do not contain hidden workflow logic;
- queries avoid obvious N+1/unbounded reads;
- migrations preserve data and match the approved implementation contract;
- constraints/indexes support the required invariants/query shape;
- multi-write operations are atomic where required;
- locks/transactions are scoped and justified;
- API responses do not leak internal fields;
- focused backend tests cover the actual contract;
- no unrelated dependency, config, migration, or generated-file change exists.

## Final Backend Rule

> Implement the approved backend contract with thin HTTP boundaries, explicit tenant-safe queries, focused use cases, safe PostgreSQL persistence, deterministic tests, and no speculative architecture.
