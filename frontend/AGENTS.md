# TestLabUz Frontend Engineering Rules

## 1. Scope

This file applies automatically to implementation work that changes files under `frontend/`.

Read it together with the root `AGENTS.md`.

The approved implementation contract defines the required UX behavior, routes, API contract, state transitions, validation, accessibility, tests, and verification commands. This file defines the Flutter engineering standard for implementing that contract.

The root `AGENTS.md` remains authoritative for general engineering, security, verification, context-discipline, Git, and repository-safety rules. This file adds frontend-specific rules and must not be used to infer missing product behavior.

If the approved implementation contract is materially incomplete or conflicts with this file or the current frontend implementation, report the exact blocker instead of making a product, UX, API, architecture, security, or lifecycle decision.

## 2. Frontend Architecture

Use the existing Flutter architecture and established project patterns.

Prefer feature-first organization with the applicable responsibility flow:

```text
Presentation
  -> Application / Controller / Notifier
  -> Repository contract
  -> Data source / DTO / configured Dio client
```

Use `data / domain / presentation` separation where it provides a real boundary.

Create only the files and abstractions needed for the current approved implementation contract.

Do not introduce a second router, state-management framework, HTTP client, serialization approach, design system, storage abstraction, or competing application architecture unless the approved implementation contract explicitly requires it.

## 3. Presentation Responsibilities

Widgets and screens are responsible for:

- rendering;
- user interaction;
- forms;
- layout;
- focus and keyboard behavior;
- accessibility semantics;
- presentation-specific formatting;
- displaying application state.

Widgets must not:

- call Dio directly;
- build raw API URLs;
- parse raw JSON;
- own persistent storage;
- implement authoritative authorization or business rules;
- coordinate unrelated features;
- mutate repositories or global state outside the approved application boundary.

Keep screens understandable. Extract focused widgets when they own a reusable or independently testable presentation responsibility.

Do not split simple UI into meaningless tiny widgets or create one universal widget controlled by many unrelated flags.

## 4. Application State and Riverpod

Use Riverpod according to the existing project pattern.

Controllers/Notifiers/providers should own one focused feature or use-case state boundary.

Do not create:

- global mutable singleton state;
- God Notifiers that coordinate unrelated features;
- parallel caches for the same resource without an explicit task requirement;
- hidden state shared through static fields;
- provider dependency cycles.

Keep dependencies injectable and testable.

State models should communicate meaningful states rather than relying on loosely related booleans.

Use sealed classes/enums/value objects only when they improve correctness and readability; do not create a complex state machine for a simple task without a concrete risk.

## 5. Async Ownership and Stale Completion Safety

Apply request/session/target ownership safeguards when asynchronous work can outlive its current route, resource, session, controller, or operation.

Relevant safeguards may include:

- immutable request/operation keys;
- generation counters;
- target/session identity checks;
- mounted/disposed checks;
- cancellation or stale-result rejection;
- duplicate mutation suppression.

A stale completion must not overwrite current data, publish feedback to a newer session/target, close the wrong dialog, restore focus to an obsolete control, or navigate from an obsolete operation.

Async ownership must be anchored to the actual operation/session/target identity, not only to Widget mounted state when the controller/provider can outlive the originating Widget.

Equivalent state rebuilds must not invalidate a still-current operation unless the approved implementation contract defines that behavior.

Do not introduce elaborate ownership machinery when the approved implementation contract has no asynchronous lifetime risk.

## 6. Routing and Navigation

Use the existing GoRouter structure, route names, helpers, guards, and canonical path conventions unless the approved implementation contract explicitly changes them.

Do not create duplicate route families or ad-hoc navigation paths.

Route parsing and target identity must remain explicit and testable.

Direct route entry must fail safely when the location or session context is invalid.

UI route guards improve UX only. They do not replace backend authorization.

Navigation after mutation/read completion must occur only when the originating session, route, target, and operation are still current.

Do not navigate from stale async completions.

## 7. Data Layer and Dio

Use the existing configured Dio/API client.

Feature code must not recreate:

- base URL handling;
- authentication headers;
- timeout configuration;
- common envelope parsing;
- global auth/session reconciliation;
- shared safe logging;
- common transport failure mapping.

Data sources own HTTP method/path/query/body/header construction.

Repositories expose typed application-facing operations and failure semantics.

Widgets must not know transport details.

Do not log bearer tokens, credentials, private payloads, or raw sensitive response bodies.

Do not add automatic retry/replay for mutations unless the implementation task explicitly defines a safe retry contract.

## 8. DTOs, Parsing, and Public Contracts

Use typed DTOs and models.

Do not pass raw `Map<String, dynamic>` through Widgets or application state when a typed boundary is appropriate.

Transport DTOs should validate the exact contract required by the approved implementation contract, including relevant:

- required keys;
- extra/unknown keys;
- types;
- nullability;
- identifier formats;
- timestamp formats;
- enum values;
- cross-field invariants.

Do not silently accept malformed success payloads as valid data.

Keep API machine values separate from localized or human-readable labels, and never use display labels as application control values.

Do not expose raw JSON or protected transport fields to presentation code unless the approved implementation contract explicitly requires them.

Generated serialization code must not be edited manually. Run the established generator only when the approved implementation contract requires generated output.

## 9. Domain and Backend Authority

The frontend presents server state and submits user intent.

Do not move backend-authoritative decisions into Flutter for convenience.

The frontend may perform contract-defined local validation and presentation formatting, but it must not independently decide authoritative:

- ownership;
- permission;
- lifecycle state;
- server time validity;
- final business outcome;
- protected relationship scope;
- persistent mutation success.

Local UI hiding is not authorization.

Optimistic UI is allowed only when the approved implementation contract explicitly permits it and it cannot create a false authoritative state.

When the backend rejects or contradicts local assumptions, reconcile to the server-defined state.

## 10. Failure Mapping and Error UX

Use typed failures or established structured error mapping.

Application branching must use stable transport/error categories defined by the task and existing infrastructure, not human-readable message parsing.

Keep distinct where relevant:

- validation failure;
- authentication/session failure;
- authorization failure;
- not found;
- business/state conflict;
- rate limit;
- transport uncertainty;
- malformed/unexpected response;
- server failure.

Do not display stack traces, raw exception text, URLs containing private identifiers, tokens, SQL, or protected payloads.

Do not swallow errors or leave the UI permanently loading/disabled after failure.

When an outcome is uncertain, do not present confirmed success unless the approved implementation contract defines evidence that proves success.

## 11. Forms and Local Validation

Keep form state controlled and deterministic.

Implement only the normalization and validation explicitly required by the approved implementation contract.

Do not silently trim, rewrite, normalize, or coerce user input beyond the approved contract.

Keep field-level and form-level errors distinct where relevant.

Prevent duplicate submission while an operation is active.

Cancel, close, Escape, reset, and focus restoration must follow the approved implementation contract.

A reset must update both the visible controls and the authoritative draft state.

Do not send empty or unchanged mutations when the approved implementation contract defines no-op behavior.

## 12. Loading, Empty, Data, and Mutation States

Data-driven UI should intentionally handle the states required by the task, typically:

```text
loading
data
empty
error
```

Mutation flows should intentionally handle the states required by the task, such as:

```text
idle
editing / confirming
submitting
success
failure
reconciliation
```

Do not reuse stale data as current confirmed data without an explicit stale-state presentation.

Do not show actions that require confirmed current data while the view is loading, failed, stale, not found, or ineligible.

Do not create unnecessary state variants that have no distinct behavior or presentation.

## 13. Caching and Invalidation

Reuse existing repository/provider cache ownership.

Do not create a second cache for the same resource unless explicitly required.

Invalidation must be narrow and contract-defined.

Preserve retained query/filter/sort/page state when the approved implementation contract requires it.

Do not optimistically patch list ordering, pagination totals, aggregates, or unrelated screens unless the approved implementation contract explicitly permits that behavior.

A mutation that may have committed before an uncertain response must not leave downstream cached data falsely authoritative.

## 14. UI Quality, Accessibility, and Responsiveness

Follow the existing theme and design-system conventions.

Use shared design tokens for genuinely repeated colors, spacing, typography, radii, and breakpoints. Keep one-off layout values local when they have no shared meaning.

Do not hardcode API values or machine codes in Widgets.

When relevant to the task, support:

- keyboard operation;
- predictable focus order;
- visible focus;
- Escape/Cancel behavior;
- semantic labels and announcements;
- associated field errors;
- progress/busy semantics;
- text scaling;
- long content;
- supported desktop window sizes;
- scrolling without overflow or focus traps;
- status communication that does not rely on color alone.

Accessibility behavior must be testable when it is part of the approved implementation contract.

## 15. Presentation Formatting

Presentation formatting may live in focused formatter/view-model helpers.

Valid examples include:

- localized labels;
- date/time display;
- number formatting;
- status text;
- responsive display decisions.

Formatting code must not become a hidden business-rule engine.

Do not recompute server-authoritative outcomes from display values.

Keep raw machine values available to application/data logic and map them to UI labels only at the presentation boundary.

## 16. Package and Platform Changes

Do not add or change Flutter packages unless explicitly required by the task.

Do not change `pubspec.lock` without a real dependency change.

Do not alter Android, iOS, Windows, Linux, macOS, or web platform files unless the approved implementation contract requires that platform change.

Do not regenerate unrelated platform files.

Do not introduce a new code generator, linter, formatter, or build tool merely to complete a focused task.

## 17. Frontend Tests

Use focused unit, repository/data-source, controller/notifier, router, and widget tests according to the changed responsibility defined by the approved implementation contract.

Test the real boundary that owns the behavior.

Relevant coverage may include:

- strict DTO parsing;
- request method/path/query/body/header construction;
- repository failure mapping;
- controller/notifier state transitions;
- duplicate request suppression;
- session/target/disposal stale completion rejection;
- route parsing and direct entry;
- form normalization/validation;
- loading/empty/error/data presentation;
- mutation feedback;
- cache invalidation;
- focus/keyboard/accessibility behavior;
- responsive layout and overflow.

Keep tests deterministic:

- use fake/injected repositories and clients;
- control async completion explicitly;
- use fake clocks/timestamps when needed;
- avoid arbitrary sleeps;
- do not call real external networks;
- do not depend on uncontrolled device time or locale.

Do not duplicate backend-authoritative business formulas in frontend tests.

Do not weaken existing tests to accommodate incorrect implementation.

## 18. Frontend Verification Boundary

Per-task verification is governed by the approved implementation contract and the root `AGENTS.md`.

Frontend engineering rules do not independently expand verification into the full frontend suite, full build, or broad E2E. Those are Stage checkpoint/integration activities unless the approved implementation contract explicitly requires broader verification for a concrete regression risk.

Narrow diagnostic test runs or focused reruns are allowed when needed to understand a failure.

## 19. Frontend Diff Review

In addition to the root diff review, verify:

- feature-first placement is correct;
- Widgets do not call Dio or parse JSON;
- DTOs/repositories/controllers have focused responsibilities;
- no competing router/client/state/cache abstraction was introduced;
- session/target/operation ownership is sufficient but not overengineered;
- stale completions cannot affect current state;
- machine values remain separate from UI labels;
- backend-authoritative behavior was not reimplemented;
- loading/error/mutation states cannot become stuck;
- invalidation is narrow and preserves required retained state;
- accessibility/focus/responsive behavior required by the task is covered;
- generated/platform/lock files changed only when justified;
- focused frontend tests cover the actual contract.

## Final Frontend Rule

> Implement the approved frontend contract with feature-first boundaries, typed transport/data models, focused Riverpod state, safe asynchronous ownership, accessible UI, deterministic tests, and no client-side reinvention of backend authority.
