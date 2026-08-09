# Codex Execution Prompt - S01-INT-003

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Approved task file:

`tasks/integration/stage-01/S01-INT-003-local-backend-runtime-postgresql-foundation.md`

Task:

`S01-INT-003 - Local Backend Runtime & PostgreSQL Foundation`

Execute only this approved task.

Before any implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read the complete approved `S01-INT-003` task.
4. Read only the locked specification sections referenced by the task.
5. Verify `S01-BE-001` is `Accepted` and its accepted result is on
   `origin/main`.
6. Verify the approved Git remote and synchronized `main`.
7. Verify Docker Engine/Desktop and Docker Compose are available.

Required task branch:

`task/s01-int-003-postgresql-runtime`

If the user already saved this approved task file and
`S01-INT-003-CODEX-PROMPT.md` into the repository before execution, treat those
exact approved preparation files as the only permitted pre-task additions.
Verify no unrelated dirty state exists, create the task branch immediately, and
do not commit them on `main`.

Follow the task's phases exactly:

1. Phase 0 - Git Preflight
2. Phase 1 - Implementation
3. Phase 2 - Read-Only Acceptance Gate
4. Phase 3 - Post-Acceptance Git Delivery

Implement only:

- Docker-based local Laravel runtime;
- official PostgreSQL 18.4 service;
- host-mounted `backend/` source;
- PostgreSQL health/startup dependency;
- separate `testlabuz` and `testlabuz_testing` databases;
- ignored local Docker environment plus tracked example;
- Laravel PostgreSQL configuration needed for local/test runtime;
- focused PostgreSQL connectivity/isolation test;
- concise local runtime instructions.

Do not implement:

- Institution/User/Role schema;
- product migrations or seed accounts;
- login/logout/auth/me/change-password;
- role authorization;
- Flutter;
- CI;
- Redis/queues/mail/object storage;
- nginx/production deployment;
- later-stage product features.

Critical rules:

- use `postgres:18.4`;
- follow PostgreSQL 18+ official volume layout;
- never commit real `.env`, DB password, app key, token, or credential;
- do not run future domain migrations just to prove database connectivity;
- tests must prove they target `testlabuz_testing`, not development DB;
- do not commit/push before the read-only acceptance gate passes;
- once Phase 2 begins, do not self-fix findings;
- Phase 2 failure => `FINAL STATUS: NOT ACCEPTED`, then stop;
- Phase 2 pass but GitHub delivery failure =>
  `FINAL STATUS: DELIVERY BLOCKED`, then stop;
- `FINAL STATUS: ACCEPTED` only after the accepted task is merged to
  `origin/main`, local `main == origin/main`, and the working tree is clean.

Never force-push, rewrite history, bypass checks, expose credentials, or start
`S01-BE-002`.

Return the complete final report required by Section 17 of the task.
