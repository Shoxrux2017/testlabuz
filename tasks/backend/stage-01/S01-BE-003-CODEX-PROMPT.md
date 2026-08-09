# Codex Execution Prompt — S01-BE-003

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Approved task file:

`tasks/backend/stage-01/S01-BE-003-sanctum-authentication-session-api.md`

Task:

`S01-BE-003 — Sanctum Authentication & Session API`

Execute **only** this approved task.

Before implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read the complete approved `S01-BE-003` task.
4. Read only its referenced locked roadmap/architecture/API sections.
5. Verify `S01-BE-002` is `Accepted` and present on `origin/main`.
6. Verify clean/synchronized `main`, approved `origin`, PostgreSQL test runtime,
   and accepted Sanctum UUID identity persistence.

Required task branch:

`task/s01-be-003-sanctum-auth-session`

If the user already saved this approved task and
`S01-BE-003-CODEX-PROMPT.md` under `tasks/backend/stage-01/`, treat those exact
approved files as the only permitted pre-task additions. Do not commit them on
`main`; create the task branch immediately and carry them into it.

Follow the exact lifecycle:

1. **Phase 0 — Git Preflight**
2. **Phase 1 — Implementation**
3. **Phase 2 — Read-Only Acceptance Gate**
4. **Phase 3 — Post-Acceptance Git Delivery**

Implement only:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

plus the focused supporting auth infrastructure required by the task:

- LoginRequest;
- credential authentication action/service;
- Sanctum Bearer token issuance;
- `last_login_at` update;
- active user/institution middleware;
- explicit login/current-user resources;
- current-token-only logout;
- named login rate limiter;
- full auth feature/security tests.

Locked public login request field is:

`login`

which maps to:

`users.login_name`

Do not rename it publicly to `login_name`.

Critical rules:

- unknown login and wrong password => same `401 invalid_credentials`;
- valid inactive user => `403 user_inactive`;
- valid institution user in inactive institution =>
  `403 institution_inactive`;
- client cannot choose role/institution;
- role/institution/status come from current persisted data;
- plaintext token returned only once in login response and never logged;
- logout revokes only current token and returns empty `204`;
- `/auth/me` returns exact locked institution context/timezone;
- already-issued token must lose normal access immediately after user or
  institution deactivation;
- logout remains available to revoke that valid token;
- login rate limiting uses existing `429 rate_limited`;
- must_change_password flag is returned but its backend gate is NOT implemented
  in this task.

Do **not** implement:

- `/auth/change-password`;
- `password_change_required`;
- role-capability policies/middleware;
- refresh-token rotation;
- logout-all/device management;
- registration/password reset/MFA;
- Flutter;
- Stage 2+ APIs.

No commit/push during implementation.

Once Phase 2 starts, do not self-fix findings.

Final-state rules:

- Phase 2 failure =>
  `FINAL STATUS: NOT ACCEPTED`
- Phase 2 pass but safe GitHub delivery failure =>
  `FINAL STATUS: DELIVERY BLOCKED`
- return
  `FINAL STATUS: ACCEPTED`
  only after merge to `origin/main`, local-main synchronization, and clean tree.

Never force-push, rewrite shared history, bypass checks, expose credentials or
tokens, or start `S01-BE-004`.

Return the complete final report required by Section 18 of the approved task.
