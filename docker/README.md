# Local Docker Runtime

This runtime is for local Laravel API development and backend testing only.
It starts the Laravel app container with the host `backend/` source mounted
and a PostgreSQL 18.4 database container with separate development and testing
databases.

## Setup

Create the ignored local Docker environment file:

```powershell
Copy-Item docker\.env.example docker\.env
```

Edit `docker/.env` and replace `POSTGRES_PASSWORD` with a local-only password.
Do not commit `docker/.env`.

Build the application image:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml build
```

Install Composer dependencies in the mounted backend source when needed:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml run --rm app composer install
```

Start the runtime:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml up -d
```

Check service state and PostgreSQL health:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml ps
```

Run backend tests against the isolated PostgreSQL test database:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app php artisan test
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app vendor/bin/pint --test
docker compose --env-file docker/.env -f docker/docker-compose.yml exec app composer validate --strict
```

Stop containers but keep them available for a quick restart:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml stop
```

Remove containers while preserving the PostgreSQL named volume:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml down
```

Remove containers and the local PostgreSQL named volume only when an intentional
clean database reset is needed:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml down -v
```
