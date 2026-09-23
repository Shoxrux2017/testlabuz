# Focused Fix Contract: S08-BE-PHASE-2-FIX-003 — PHPUnit Memory Limit

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-PHASE-2-FIX-003` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | `S08-BE-PHASE-2` run #1 — §40 full-suite gate failed on PHP memory |
| Project Owner decision | `D4 = A` (2026-09-23) |
| Area | Backend test configuration |
| Delivery | Claude opens the PR; Project Owner reviews and merges |

## 2. Problem

The §40 command `docker compose … exec -T app php artisan test` exits `2` on audited `232ebcd`:
"Allowed memory size of 134217728 bytes exhausted". The app image sets no `memory_limit`, so PHP's
128M default applies. With a higher limit the same SHA passes 2338/2338 tests (55,540 assertions)
with a peak of 167 MB. The growth is cumulative across the single PHPUnit process; no product or
test regression is involved.

## 3. Exact Change

Add to the `<php>` section of `backend/phpunit.xml`:

```xml
<ini name="memory_limit" value="512M"/>
```

- Test-only; the Docker image, dev server and the §40 command stay unchanged.
- 512M gives roughly 3× headroom over the measured peak.

### Non-Goals

- No Docker image or `docker/php` change, no command change in any contract.
- No investigation or refactor of per-test memory growth.

## 4. Acceptance Criteria

- [ ] `php artisan test` (the exact §40 command) completes with exit `0` on the merged `main`;
      recorded by the refreshed `S08-BE-PHASE-2`, not by this task.
- [ ] This task's own verification: `php artisan test --filter StudentBlitzAnswerValidationTest`
      passes, a one-off scratch test run through `php artisan test` (not committed) observes
      `ini_get('memory_limit') === '512M'` inside the PHPUnit subprocess, and `git diff --check`
      passes.
- [ ] Only `backend/phpunit.xml` changes.
