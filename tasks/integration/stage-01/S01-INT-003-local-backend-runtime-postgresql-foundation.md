# Codex Task: Local Backend Runtime & PostgreSQL Foundation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-INT-003` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Integration / local backend infrastructure` |
| Status | `Accepted` |
| Depends on | `S01-BE-001 — Laravel API Scaffold & Backend Quality Foundation (Accepted)` |
| Blocks | `S01-BE-002 — Identity Persistence Foundation` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, verification,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Create a reproducible local Docker-based Laravel + PostgreSQL runtime for
TestLabUz and prove that both development and automated backend testing use the
approved PostgreSQL infrastructure safely.

The accepted result must provide:

- a Docker Compose development environment under `docker/`;
- the real Laravel source mounted from the host `backend/` directory;
- a Laravel application container suitable for local API development;
- PostgreSQL as the relational database baseline;
- an isolated PostgreSQL test database;
- explicit database health/startup coordination;
- reproducible local setup documentation;
- a focused automated infrastructure test proving Laravel reaches the intended
  PostgreSQL test database;
- no application/domain schema implementation yet.

This task is infrastructure integration only. It must not implement
institutions, users, roles, authentication, authorization, Flutter, CI,
production deployment, or later-stage product behavior.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

The Stage 1 index defines this task as:

`S01-INT-003 — Local Laravel runtime and PostgreSQL development/test foundation`

and requires:

`S01-BE-001 = Accepted`

before this task may execute.

At the end of accepted `S01-BE-001`, the repository is expected to contain a
real Laravel 13 backend under `backend/`, including the API/error/testing
foundation, but no TestLabUz Institution/User persistence implementation.

Codex must inspect the actual repository state and must not assume that
`S01-BE-001` succeeded merely because this task file exists.

## 4. Version and Infrastructure Baseline

### 4.1 PostgreSQL

Use PostgreSQL `18.4` for this task.

Approved container baseline:

`postgres:18.4`

Use the official PostgreSQL image.

Important PostgreSQL 18 image rule:

- PostgreSQL 18 changed the image's version-specific `PGDATA`.
- The image-defined volume location for PostgreSQL 18+ is
  `/var/lib/postgresql`.
- Do not blindly reuse the pre-18 `/var/lib/postgresql/data` volume target.

Use a named Docker volume for local PostgreSQL persistence.

Do not use PostgreSQL 19 beta/development builds.

### 4.2 PHP application runtime

Use a supported official PHP CLI image compatible with Laravel 13.

Preferred baseline:

`php:8.4-cli-bookworm`

The runtime image must include only the minimum local-development extensions and
tools needed by this task, including PostgreSQL PDO support and Composer.

At minimum the application runtime must support:

- PHP CLI required by Laravel 13;
- `pdo_pgsql`;
- Composer;
- basic tools needed to install the locked Composer dependencies.

Do not add nginx, Apache, Redis, queues, supervisors, Node.js, npm, cron,
scheduler workers, mail services, object storage, or unrelated infrastructure
in this task.

For local development, Laravel's development server is sufficient.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before infrastructure changes:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced by this task.
5. Verify `S01-BE-001` is recorded as `Accepted` and its accepted implementation
   is present on `origin/main`.
6. Verify the approved `origin`.
7. Fetch remote state safely.
8. Verify local `main` and `origin/main` refer to the same accepted commit.
9. Verify no unrelated tracked modification exists.

Required task branch:

`task/s01-int-003-postgresql-runtime`

If the project owner has already placed this approved task file and/or its
matching Codex prompt into the planned `tasks/integration/stage-01/` location
before execution, Codex may treat those exact approved preparation files as the
only permitted pre-task uncommitted additions.

In that case:

- verify they are the only such additions;
- do not stage or commit them on `main`;
- create the task branch immediately from synchronized `main`;
- carry the approved files into the task branch;
- perform all implementation and commits only on the task branch.

Any other dirty/untracked project state is a blocker unless it is already
allowed by repository workflow rules.

### 5.2 Docker application runtime

Create a minimal PHP runtime definition under `docker/`, for example:

```text
docker/
  php/
    Dockerfile
```

The exact subpath may vary only if there is a clear reason.

The Dockerfile must:

- use the approved supported PHP baseline;
- install `pdo_pgsql`;
- provide Composer through an official/reliable Docker mechanism;
- set a clear application working directory;
- avoid embedding application secrets;
- avoid copying secret environment files into the image;
- remain a local-development runtime, not pretend to be the production image.

Do not copy the Laravel source into a disposable-only location as the sole
source of truth.

### 5.3 Docker Compose

Create:

`docker/docker-compose.yml`

The Compose configuration must define only the minimum services required for
this task:

1. Laravel application service.
2. PostgreSQL database service.

Requirements:

- Laravel host source at `../backend` is mounted into the application
  container.
- Application service can reach PostgreSQL by Compose service name.
- PostgreSQL uses the official `postgres:18.4` image.
- PostgreSQL uses a named persistent volume.
- PostgreSQL 18 volume mount target follows the current official image layout.
- PostgreSQL has a real healthcheck.
- Application startup must depend on PostgreSQL health rather than only
  container creation order.
- Do not use `container_name`; allow Compose project isolation.
- Do not use `network_mode: host`.
- Do not expose services on all host interfaces unless required.
- Host-exposed development ports should bind to `127.0.0.1`.
- Database host port should be configurable to avoid collision with an
  already-installed PostgreSQL instance.
- Application port should be configurable.
- Do not add production secrets to Compose YAML.

Recommended service names:

```text
app
postgres
```

Recommended logical databases:

```text
testlabuz
testlabuz_testing
```

Recommended non-secret database username:

```text
testlabuz
```

Database passwords must come from ignored local environment configuration, not
from tracked Compose configuration.

### 5.4 Local Docker environment template

Create:

`docker/.env.example`

It may define only non-sensitive local-development configuration and safe
placeholders such as:

- Compose project name;
- application port;
- PostgreSQL host port;
- local database name;
- test database name;
- local database username;
- a clearly marked placeholder for local database password.

The real:

`docker/.env`

must remain ignored and untracked.

For Codex verification, it may create an ignored local `docker/.env` derived
from the example.

If Codex needs a local password for runtime verification:

- use a local-only value;
- preferably generate a nontrivial value;
- do not print it;
- do not place it in the completion report;
- do not commit it.

Do not add production/staging credentials.

### 5.5 Isolated PostgreSQL test database

A fresh local PostgreSQL volume must initialize both:

```text
testlabuz
testlabuz_testing
```

The test database must be separate from the normal development database.

Use the smallest reproducible init mechanism under `docker/postgres/`.

A simple initialization SQL/script is acceptable.

The initialization mechanism must:

- create only the additional test database/infrastructure needed here;
- not create TestLabUz domain tables;
- not create institutions/users/roles;
- not seed product users;
- not create production-like data;
- not contain secrets.

No business migrations should be applied by this task.

### 5.6 Laravel PostgreSQL configuration baseline

Adjust Laravel's committed configuration/example/test configuration only as
needed so the approved backend runtime uses PostgreSQL rather than silently
falling back to SQLite.

Requirements:

- normal local runtime uses the development PostgreSQL database;
- automated backend tests run against the isolated
  `testlabuz_testing` PostgreSQL database;
- the database password is inherited from runtime environment and is not
  committed in `phpunit.xml`, source, or example files;
- no actual `.env` is committed;
- `.env.example` remains secret-free;
- no domain migration is executed merely to prove connectivity.

The exact implementation may use environment overrides in Compose plus
test-safe Laravel configuration.

### 5.7 PostgreSQL connectivity test

Add one focused infrastructure test under the backend test suite proving that
the Laravel database layer is using PostgreSQL and the isolated testing
database.

Example logical test path:

`backend/tests/Feature/Infrastructure/PostgreSqlConnectionTest.php`

The test must prove at least:

- active Laravel driver is `pgsql`;
- current database is the approved test database, not the development database;
- a simple PostgreSQL query succeeds;
- PostgreSQL server major version is `18`.

The test must not require a TestLabUz business table.

It must not create a fake production API endpoint.

### 5.8 Local development instructions

Add concise operational documentation in an appropriate existing repository
workflow/development document or a narrowly scoped infrastructure README under
`docker/`.

Do not create a large duplicate architecture document.

Document exact safe commands for:

1. creating local `docker/.env` from the example;
2. building the application image;
3. installing Composer dependencies in the container when needed;
4. starting the runtime;
5. checking service health;
6. running the Laravel test suite against PostgreSQL;
7. stopping containers;
8. stopping containers while preserving the database volume;
9. explicitly removing the local database volume when a developer intentionally
   wants a clean reset.

Never make destructive volume removal part of the normal stop command.

## 6. Expected Logical Structure

After this task, relevant structure should resemble:

```text
testlabuz/
  backend/
    AGENTS.md
    ...
    tests/
      Feature/
        Infrastructure/
          PostgreSqlConnectionTest.php

  docker/
    docker-compose.yml
    .env.example

    php/
      Dockerfile

    postgres/
      init/
        ...

  tasks/
    integration/
      stage-01/
        S01-INT-003-local-backend-runtime-postgresql-foundation.md
        S01-INT-003-CODEX-PROMPT.md
```

Exact generated backend files come from accepted `S01-BE-001`.

Do not reorganize the backend in this task.

## 7. Authoritative Specification References

| Document | Exact section | Requirement used |
|---|---|---|
| `docs/06-roadmap.md` | `2.1 Vertical Development` | Each stage integrates required layers instead of building an entire backend ahead |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Current Stage 1 boundary |
| `docs/07-architecture.md` | `2.1 Backend` | Laravel REST API is the backend authority |
| `docs/07-architecture.md` | `2.4 Database` | Relational database; PostgreSQL is approved baseline |
| `docs/07-architecture.md` | `2.6 Local Development` | Docker for backend infrastructure; real Laravel source remains on host and is mounted into Docker |
| `docs/07-architecture.md` | `5. Recommended Project Structure` | Approved `backend/`, `frontend/`, `docker/` repository shape |
| `docs/07-architecture.md` | `32. Testing Architecture` | Testing is part of architecture |
| `docs/07-architecture.md` | `36. Deployment Architecture` | Separate local/testing/staging/production; reproducible local and isolated test data |
| `AGENTS.md` | Current Git/task workflow sections | Task branch, acceptance, delivery, scope, and Git safety |
| `backend/AGENTS.md` | Backend baseline/testing/security sections | Laravel/PostgreSQL backend rules and quality requirements |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-INT-003` row and dependency table | Task order and dependency on accepted `S01-BE-001` |

## 8. External Technical Baseline References

These technical references do not replace locked TestLabUz product contracts.

For implementation, Codex should follow current official documentation for:

- Docker Compose service health/dependency semantics;
- official PostgreSQL 18 Docker image storage layout;
- PostgreSQL 18 supported/current stable major line.

Task preparation baseline on `2026-08-09`:

- PostgreSQL current stable major: `18`;
- current PostgreSQL 18 minor used here: `18.4`;
- PostgreSQL 19 is still a development/beta line and must not be used;
- official PostgreSQL Docker image for 18+ defines its volume at
  `/var/lib/postgresql`.

If the environment contradicts these exact assumptions in a way that affects
safe implementation, stop and report rather than silently selecting a
different database major.

## 9. Security and Configuration Rules

- No secret/password/token may be committed.
- No real `.env` file may be committed.
- No GitHub credential may be placed in Docker configuration.
- PostgreSQL should not listen publicly on `0.0.0.0` host bindings by default.
- The local database port must bind to loopback only when exposed.
- Use normal Docker network service discovery between `app` and `postgres`.
- Do not add `trust` authentication to PostgreSQL.
- Do not disable database password authentication merely for convenience.
- Do not put passwords in Dockerfile layers.
- Do not expose Laravel `APP_KEY` or other runtime secrets.
- Do not add production database credentials.
- Do not weaken the existing root/backend ignore rules.
- Do not use privileged containers.
- Do not mount the Docker socket.
- Do not add unnecessary host filesystem mounts.
- Do not run destructive database commands against an existing unrelated local
  PostgreSQL installation.

## 10. Requirements

### 10.1 Functional Requirements

1. `S01-BE-001` is independently verified as `Accepted`.
2. Work occurs on `task/s01-int-003-postgresql-runtime`.
3. `docker/docker-compose.yml` defines exactly the required Laravel and
   PostgreSQL services for this task.
4. Host `backend/` source is mounted into the application service.
5. Laravel application runtime uses a supported PHP version compatible with
   Laravel 13.
6. Application runtime has `pdo_pgsql`.
7. Composer is usable inside the application container.
8. PostgreSQL service uses official `postgres:18.4`.
9. PostgreSQL 18 data volume uses the correct v18+ official image mount target.
10. PostgreSQL service has a healthcheck.
11. Application service waits for PostgreSQL health.
12. Development PostgreSQL database is `testlabuz`.
13. Isolated testing PostgreSQL database is `testlabuz_testing`.
14. Real local database password remains outside tracked files.
15. Laravel normal runtime resolves PostgreSQL configuration.
16. Backend tests can run against `testlabuz_testing`.
17. Focused PostgreSQL infrastructure test proves driver/database/server
    connectivity.
18. No TestLabUz business/domain schema is created or migrated.
19. No Institution/User/Role fixture or seed is created.
20. Local setup/teardown/test commands are documented.
21. Existing backend tests continue to pass in the canonical containerized
    PostgreSQL test environment.
22. No frontend change occurs.
23. No CI/production deployment infrastructure is introduced.

### 10.2 Architecture Requirements

- Keep all real Laravel source under host `backend/`.
- Docker infrastructure belongs under `docker/`.
- Do not copy the only application source into an image/container.
- Keep local runtime simple: one app service + one PostgreSQL service.
- Do not introduce a reverse proxy before it is needed.
- Do not introduce Redis/cache/queue infrastructure before an approved feature
  needs it.
- Do not introduce custom Docker networks unless the default Compose network is
  insufficient.
- Do not hardcode container names.
- Keep test database isolation explicit.
- Avoid shell scripts where a simple portable Compose/SQL configuration is
  sufficient, especially where Windows host line endings would create
  unnecessary fragility.

### 10.3 Data / Migration Boundary

This task establishes database infrastructure, not the TestLabUz schema.

Therefore:

- existing framework migration files may remain in source if they were part of
  accepted `S01-BE-001`;
- do not run application migrations against the development database merely to
  validate PostgreSQL;
- do not redesign/remove future identity migration files in this task unless
  they were accidentally executed/created by this task itself;
- `S01-BE-002` owns the approved Institution/User identity persistence design;
- connectivity verification must use raw/simple PostgreSQL queries or
  migration-independent test logic.

## 11. Acceptance Criteria

- [ ] Dependency `S01-BE-001` is `Accepted` on `origin/main`.
- [ ] Task branch is `task/s01-int-003-postgresql-runtime`.
- [ ] `docker/docker-compose.yml` exists and validates with Docker Compose.
- [ ] Only required `app` and `postgres` runtime services are introduced.
- [ ] Laravel source is mounted from host `backend/`.
- [ ] Application container starts successfully.
- [ ] `pdo_pgsql` is available in the application runtime.
- [ ] Composer works in the application runtime.
- [ ] PostgreSQL image is exactly on the approved `18.4` line.
- [ ] PostgreSQL healthcheck reaches `healthy`.
- [ ] Application service is ordered on database `service_healthy`.
- [ ] PostgreSQL persistence uses a named volume at the PostgreSQL 18+
      compatible target.
- [ ] Database host exposure, if enabled, binds only to loopback.
- [ ] Development DB is `testlabuz`.
- [ ] Test DB is separate as `testlabuz_testing`.
- [ ] `docker/.env.example` exists and contains no real secret.
- [ ] `docker/.env` is ignored/untracked.
- [ ] Laravel uses `pgsql` in the containerized development runtime.
- [ ] Backend tests use `pgsql` and `testlabuz_testing`.
- [ ] PostgreSQL infrastructure test passes and proves PostgreSQL major 18.
- [ ] Full existing backend test suite passes in the canonical container test
      runtime.
- [ ] No application migration/domain table was applied to prove connectivity.
- [ ] No Institution/User/Role domain implementation was introduced.
- [ ] No auth endpoint/logic was introduced.
- [ ] No frontend change occurred.
- [ ] No CI, Redis, queue, mail, file-storage service, reverse proxy, or
      production deployment setup was introduced.
- [ ] No secret or credential is tracked.
- [ ] Locked `docs/01–09` remain unchanged.
- [ ] Safe local setup/test/stop/reset instructions are present.

## 12. Tests and Verification

### 12.1 Git preflight

Run safe equivalents of:

```text
git rev-parse --show-toplevel
git status --short
git branch --show-current
git remote -v
git fetch origin
git rev-parse main
git rev-parse origin/main
```

Verify accepted dependency evidence from repository task/index state.

### 12.2 Docker availability

Before creating runtime infrastructure, verify:

```text
docker version
docker compose version
docker info
```

If Docker Desktop/Engine is unavailable, stopped, inaccessible, or incompatible
with the required Compose features, stop and report the blocker.

Do not install or reconfigure Docker globally from this task.

### 12.3 Compose validation

From repository root, use the committed example configuration plus an ignored
local environment file.

Run safe equivalents of:

```text
docker compose --env-file docker/.env -f docker/docker-compose.yml config
docker compose --env-file docker/.env -f docker/docker-compose.yml build
docker compose --env-file docker/.env -f docker/docker-compose.yml up -d
docker compose --env-file docker/.env -f docker/docker-compose.yml ps
```

The database must become healthy.

### 12.4 Runtime checks

Run safe equivalents of:

```text
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app php --version
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app php -m
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app composer --version
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app php artisan --version
```

Verify `pdo_pgsql` is loaded.

### 12.5 Database checks

Verify PostgreSQL directly without printing the password.

Safe checks should prove:

- PostgreSQL server version is 18.x;
- development database exists;
- test database exists;
- expected user owns/can access both;
- app network connection works;
- no unexpected application/domain tables were created by this task.

Do not dump environment values or credentials into logs/report.

### 12.6 Backend tests

Run the canonical test suite inside the app container against the isolated test
database.

At minimum:

```text
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app php artisan test
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app vendor/bin/pint --test
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app composer validate --strict
```

If accepted `S01-BE-001` defines additional mandatory backend quality commands,
run them too.

### 12.7 Runtime API smoke

With the app service running, perform a local HTTP smoke check against the
existing accepted API foundation.

Do not add a new production health endpoint merely for this task.

Use an already-approved API behavior such as an unknown `/api/v1/...` route and
confirm the accepted JSON 404 contract still works over the Docker-hosted
runtime.

### 12.8 Isolation verification

Prove automated tests target `testlabuz_testing`, not `testlabuz`.

The infrastructure test must fail if accidentally pointed to the development
database.

Do not rely only on matching an environment variable string; verify the current
database through PostgreSQL/Laravel connection state.

### 12.9 Shutdown behavior

Normal stop must preserve database data:

```text
docker compose --env-file docker/.env -f docker/docker-compose.yml down
```

Do not use `-v` as the normal stop command.

A volume-removal/reset command may be documented as an explicit destructive
developer action, clearly labeled as such.

### 12.10 Scope / secret checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- frontend
```

Also inspect tracked/staged filenames and text for:

- `.env`;
- database passwords;
- private keys/certificates;
- GitHub tokens;
- Laravel app key;
- credential-bearing URLs.

Do not print discovered secret values.

## 13. Manual Smoke Check

1. Start Docker Compose from a fresh/stopped state.
2. Confirm PostgreSQL becomes healthy.
3. Confirm the Laravel app service starts after database health.
4. Confirm local API responds on the configured loopback port.
5. Confirm existing `/api/v1` JSON error behavior is intact.
6. Run backend tests and confirm they use `testlabuz_testing`.
7. Stop Compose normally.
8. Start it again and confirm normal development PostgreSQL volume persists.
9. Confirm no product/domain data had to be created to prove the runtime.

## 14. Explicit Non-Goals

- Institution table/schema implementation.
- User table/schema redesign.
- Role enum persistence.
- Sanctum authentication business flow.
- Login/logout/current-user endpoints.
- Password-change gate.
- Authorization middleware/policies beyond accepted scaffold.
- Product seed accounts.
- Flutter.
- GitHub Actions / CI.
- Production Docker image.
- nginx/Apache/reverse proxy.
- Redis.
- queues/workers.
- scheduler/cron.
- Mailpit/mail server.
- MinIO/object storage.
- file upload/storage configuration.
- PostgreSQL extensions not required by this task.
- database backup/restore strategy.
- production/staging database configuration.
- Kubernetes/cloud infrastructure.
- schema migrations from future tasks.

## 15. Stop Conditions

Stop and report instead of improvising if:

- `S01-BE-001` is not `Accepted`;
- accepted `S01-BE-001` implementation is absent from `origin/main`;
- local `main` cannot be safely synchronized to `origin/main`;
- there is unrelated dirty working-tree state;
- `origin` is unexpected;
- Docker Engine/Desktop is unavailable;
- Docker Compose required features are unavailable;
- the official required PostgreSQL image cannot be pulled due a persistent
  dependency/environment issue;
- the existing backend is not a working accepted Laravel 13 scaffold;
- implementing this task would require changing locked product contracts;
- implementing it requires Institution/User domain schema now;
- implementing it requires installing global/system dependencies outside Docker;
- a correct result requires destructive cleanup of unrelated Docker volumes,
  containers, or host database data;
- a port conflict cannot be solved through the approved configurable local
  ports;
- a secret would need to be committed;
- a safe solution requires force-push/history rewrite/check bypass;
- material scope expansion is required.

## 16. Execution, Acceptance, and GitHub Delivery Workflow

### Phase 0 — Git Preflight

1. Complete Section 5.1.
2. Verify Docker tooling.
3. Create/switch to:
   `task/s01-int-003-postgresql-runtime`.
4. Ensure this approved task and matching Codex prompt exist on the task branch.
5. Update only the `S01-INT-003` row in `tasks/STAGE_01_TASK_INDEX.md` to
   reflect `Approved` while implementation is in progress if required by the
   current repository workflow.
6. Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- Compose validation;
- build/start;
- database health checks;
- Laravel/PostgreSQL connectivity verification;
- infrastructure test;
- full backend tests;
- Pint;
- Composer validation;
- HTTP smoke;
- secret/scope checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- this complete task;
- root/backend `AGENTS.md`;
- referenced locked contracts;
- full task branch diff;
- test and runtime evidence.

During this phase:

- no file edits;
- no auto-fixes;
- no new staging;
- no commit;
- no push;
- no merge.

If any blocking/material requirement fails:

```text
FINAL STATUS: NOT ACCEPTED
```

Return exact findings and stop.

Do not self-fix after Phase 2 begins.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes.

1. Set this task status to `Accepted`.
2. Update `tasks/STAGE_01_TASK_INDEX.md` consistently:
   - task status `Accepted`;
   - review status `PASS`;
   - delivery status finalized after merge.
3. Re-run final diff/secret checks.
4. Stage only approved task changes.
5. Create one focused commit.

Preferred commit subject:

`build(dev): add PostgreSQL local runtime`

Commit body:

`Task: S01-INT-003`

6. Push task branch to `origin`.
7. Create PR to `main` using authenticated GitHub tooling when available.
8. Do not bypass required checks.
9. Merge only when safely mergeable and all required checks pass.
10. Remove the remote task branch after merge if normal repository policy
    permits.
11. Synchronize local `main` with `origin/main` using safe fast-forward
    operations.
12. Verify:
    - local `main == origin/main`;
    - clean working tree;
    - accepted task/index state exists on `origin/main`.

If Phase 2 passes but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S01-BE-002`.

If all delivery checks pass:

```text
FINAL STATUS: ACCEPTED
```

## 17. Required Codex Final Report

Return:

1. **Final status** — exactly one:
   - `ACCEPTED`
   - `NOT ACCEPTED`
   - `DELIVERY BLOCKED`
2. **Dependency/Git preflight**.
3. **Docker environment evidence**:
   - Docker version;
   - Compose version;
   - task branch.
4. **Infrastructure summary**.
5. **Changed files** grouped by Docker, backend test/config, docs/task
   bookkeeping.
6. **Runtime evidence**:
   - app service state;
   - PostgreSQL health;
   - PHP runtime version;
   - `pdo_pgsql`;
   - Composer availability.
7. **Database evidence**:
   - PostgreSQL version;
   - development DB;
   - test DB;
   - test isolation;
   - no domain migrations applied.
8. **Acceptance gate findings**.
9. **Acceptance criteria** PASS/FAIL individually.
10. **Tests / quality gates** exact commands/results.
11. **Security evidence** without printing secret values.
12. **HTTP smoke result**.
13. **GitHub delivery evidence**:
    - commit hash/subject;
    - pushed branch;
    - PR reference if available;
    - merge result;
    - local main hash;
    - origin/main hash;
    - final clean status.
14. **Scope confirmation** — explicitly confirm no identity/auth/Flutter/CI/
    later-stage feature was implemented.
15. **Remaining blockers/deviations**.

Do not start `S01-BE-002`.
