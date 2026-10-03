# Focused Fix Contract: DEP-FIX-001 — Composer Security Advisories

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `DEP-FIX-001` (platform-wide; not a Stage task) |
| Origin | `composer audit` at the Stage 9 closure (`tasks/STAGE_09_CLOSURE_REVIEW.md` §11, `CL9-14`) |
| Project Owner decision | `S09-CL-D3` (2026-10-03): a separate dependency-update task right after the Stage 9 closure, before any Stage 10 code |
| Area | Backend dependencies |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Baseline | `origin/main` `57d9949b5cb4242fa64a8e79f7d7afc6c4507869` (Stage 9 closed) |

## 2. Problem

`composer audit` reports 8 advisories in 3 locked packages. All of them were present before Stage 9.

| Package | Locked | Advisories | Fixed from |
|---|---|---|---|
| `league/commonmark` (through `laravel/framework`) | `2.9.0` | 5 high, 1 medium: denial of service in the table, attributes and smart-punctuation extensions, an `on*` filter bypass, a raw-HTML filter bypass | `2.10.2` |
| `laravel/framework` | `13.24.0` | 1 low: XSS in the debug page (`CVE-2026-102279`) | `13.30.0` |
| `league/flysystem` (through `laravel/framework`) | `3.35.2` | 1 low: the control-character path check is bypassed by malformed UTF-8 (`CVE-2026-102601`) | `3.36.0` |

Exposure today is low. No application code renders Markdown. The debug page is shown only with
`APP_DEBUG=true`. Private files are stored under server-generated paths
(`App\Support\Files\PrivateFileStorage`). The update is still required: the advisories are known, and the
fixes ship within the existing version constraints.

## 3. Exact Contract

- Update exactly these three locked packages:
  - `laravel/framework` `13.24.0` → `13.34.0`;
  - `league/commonmark` `2.9.0` → `2.10.3`;
  - `league/flysystem` `3.35.2` → `3.36.0`.

  The update command is `composer update laravel/framework league/commonmark league/flysystem`, without
  `--with-dependencies`.
- `backend/composer.json` does not change. Every new version satisfies the constraints that are already
  declared.
- No other locked package changes. A broader update (`--with-dependencies`) would move 45 packages,
  including the major versions of Guzzle 7 → 8, PSR-7 2 → 3 and `symfony/console` 7 → 8. That is not
  needed for any advisory and is out of scope.
- `composer audit` reports no advisory.
- No application behavior changes. Every existing test passes unchanged.

### Non-Goals

- No application code, test, migration, configuration, Docker or frontend change.
- No other dependency update, constraint change or new package.

## 4. Expected Files

```text
backend/composer.lock
tasks/backend/DEP-FIX-001-composer-security-advisories.md
tasks/README.md
tasks/STAGE_09_TASK_INDEX.md   (records that closure PR #314 merged; next gate)
```

## 5. Acceptance Criteria

- [ ] `composer.lock` differs from the baseline only in the three packages above, plus the lock metadata
      that Composer always rewrites (`plugin-api-version`, if it changes).
- [ ] `composer validate --strict` and `composer audit` pass.
- [ ] The full backend suite passes with the new versions installed.
- [ ] `pint --test` passes.
- [ ] A fresh-context review compares the framework changes between `13.24.0` and `13.34.0` with the areas
      the application relies on and finds no P1 or P2. Those areas are:
      - exception rendering in `bootstrap/app.php`;
      - validation;
      - JSON resources and responses;
      - database transactions and locks;
      - the scheduler's `withoutOverlapping`;
      - terminating callbacks;
      - Sanctum authentication;
      - the filesystem.

## 6. Verification

```text
composer update laravel/framework league/commonmark league/flysystem --no-interaction
composer validate --strict
composer audit
php artisan test            (full backend suite; memory_limit 512M from phpunit.xml)
vendor/bin/pint --test
git diff --check
```

A framework update changes runtime code under every request. That is why the full backend suite is
required here instead of focused tests. The frontend is not affected. The Stage 9 integration evidence
records the runtime it ran on (`laravel/framework` `13.24.0`). The next real-stack integration (Stage 10)
runs on the new versions.

## 7. Review Record

A fresh-context read-only review compared the framework source of `13.24.0` and `13.34.0`, and flysystem
`3.35.2` and `3.36.0`, with the areas the application uses. Result: `PASS`, P1 = 0, P2 = 0.

Informational P3, no change required:
- **Multipart input wins over a same-named file part.** A malformed answer upload that sends both a text
  field and a file part named `file` now gets `422` instead of storing the file. The client sends only the
  file part.
- **Wildcard rules check empty-string keys.** `.*` rules now also validate an array item whose key is `""`.
  Malformed input now gets `422` earlier; well-formed input is unchanged.
- **`db:seed --class=…` progress lines.** The command now prints progress lines. No test or script parses
  that output.
- **Wider framework constraints.** The new framework allows Guzzle 8, PSR-7 3, `guzzlehttp/uri-template` 2
  and newer `brick/math`. The locked versions are unchanged, so later updates must stay scoped, as this one
  is.

Unchanged for this application:
- exception rendering, the guest redirect and the validation error shape;
- JSON resources and float encoding;
- transactions, locks and the PostgreSQL grammar;
- the scheduler mutex;
- terminating callbacks;
- Sanctum and rate limiting;
- file storage and download: the application's server-generated ASCII paths pass the new flysystem check;
- Markdown: not used.
