# Django product starter

A Django `startproject --template` foundation for agent-driven product work.
The **generated project** is the artifact, and CI validates it from the local working copy.

Django 6.1 / Python 3.13 owns the domain, PostgreSQL, authorization and tasks. React,
TypeScript and Vite own product presentation. The UI uses Tailwind v4, shadcn/ui,
React Router and TanStack Query. Dependencies are locked with uv and pnpm.

## Generate and run

Install uv, Just, Node 22.12+, pnpm 10.28.1 and Docker with Compose. Django and Vite run directly
on your machine; Docker Compose runs only the development PostgreSQL. Generate with Django's standard command:

```sh
uv run --no-project --with django==6.1.1 django-admin startproject \
    --template=https://github.com/teoruiz/django-startproject/archive/refs/heads/main.zip \
    --extension=py --exclude=.git \
    my_product
cd my_product
just bootstrap
just up
```

For a clean local checkout, replace the template URL with its absolute directory path.
`--extension=py` renders only Python; frontend, Just and GitHub Actions expressions stay intact.
The explicit `--exclude=.git` keeps the `.github` workflow directory, which Django otherwise skips
with other hidden directories. No Git repository is created automatically.

Use an archive or a clean checkout for normal generation: Django copies local files, including
`.env` and installed dependencies. For testing changes from a working checkout, `just template-test`
handles secret/cache filtering internally and then invokes the same Django command.

Bootstrap copies `.env-dist` to `.env` if needed, installs locked dependencies into `.venv` and
`frontend/node_modules`, starts PostgreSQL 17 and applies migrations. It never upgrades dependencies or resets data.
`just up` starts PostgreSQL if needed, then runs Django (`uv run ... runserver`) and Vite (`pnpm dev`)
in one terminal with `django |` / `vite |` prefixed logs. Ctrl-C stops both; if either server exits,
the other is stopped and `just up` fails.

Open **http://localhost:5173**. Vite proxies relative `/api/...` calls to Django at port 8000.
Django admin is at **http://localhost:8000/admin/** and Ninja docs at **http://localhost:8000/api/docs**.
Both servers listen on 127.0.0.1 only, and PostgreSQL is published only on `127.0.0.1:5432`.
Change `POSTGRES_PORT`, `DJANGO_PORT` or `FRONTEND_PORT` in `.env`; `DATABASE_URL` and
`CSRF_TRUSTED_ORIGINS` derive from them. Create your first account in a second terminal:

```sh
just manage createsuperuser
```

Use that account's **email and password** on the React Account page. It signs in through
allauth Headless and renders the typed response from authenticated `/api/me`.
The starter deliberately has no shared default credentials and public signup is closed.
Create ordinary users through Django admin. These are administrator-created accounts: users can sign in
and out, but cannot yet register themselves, reset a forgotten password or verify their email through React.
See [authentication and deployment details](docs/architecture.md).

## Daily commands

```sh
just up                   # PostgreSQL + Django + Vite; Ctrl-C stops both servers
just backend              # PostgreSQL + Django only
just frontend             # Vite only (proxies /api to DJANGO_PORT)
just stop                 # stop servers started by up/backend/frontend in another terminal
just down                 # stop servers and the PostgreSQL container; data volume is kept
just db                   # start only PostgreSQL; just db-logs -f follows its logs
just manage <command>     # manage.py through uv, e.g. shell, createsuperuser
just test                 # pytest against development PostgreSQL (starts it if needed)
just lint                 # Ruff and frontend ESLint/Prettier checks
just typecheck            # basedpyright + TypeScript
just frontend-build       # frontend/dist, no hosting assumption
just api-generate         # export installed schemas and regenerate TypeScript
just api-check            # fail if generated contracts have drifted
just check                # lint, types, contracts, build and PostgreSQL tests
just manage makemigrations
just manage migrate
```

`just down` never deletes data. To erase this project's database, run `docker compose down --volumes`
explicitly and then `just bootstrap`. Editors should use the project interpreter at `.venv/bin/python`
(created by `uv sync`; basedpyright already points at `.venv`). `uv run` is the supported way to invoke
Python tools; activating the virtual environment is optional.

Use `uv add` / `uv remove` and `pnpm --dir frontend add` / `remove` for dependencies.
Commit `uv.lock` and `frontend/pnpm-lock.yaml`. `uv run --locked` keeps `.venv` in sync; restart
the servers after dependency changes. `just upgrade` is an explicit dependency update.
`just format` fixes formatting. Optional Git hooks: `uv run pre-commit install`.
The pyproject's `django-product` name is package metadata, independent of the generated directory name.

The checked-in TypeScript contracts come from Ninja and installed allauth OpenAPI schemas, never
handwritten copies. Export does not need a running server or database. Commit regenerated `api.d.ts`
and `auth.d.ts` after API/settings/dependency changes. The client uses openapi-fetch and relative URLs.

## Validate the template

Run these **in the template checkout**, not in a generated application:

```sh
just template-test             # fresh temporary project, SQLite; no external services
just template-test compose     # fresh project, Docker PostgreSQL, host servers and release-image build
```

Both paths install locked dependencies, check Django, apply migrations, test auth/CSRF/tasks,
check migration drift, lint, typecheck, verify generated contracts and build the frontend.
The Compose path runs the generated project's own `just bootstrap` and `just test` against Docker
PostgreSQL, then starts the host servers with `just up` and checks login, CSRF, `/api/me` and the task
example through the Vite proxy. It verifies that Ctrl-C, a crashing server and `just stop` all leave no
server processes, that `just down` stops PostgreSQL, and builds the release image.
It picks free ports; set `TEMPLATE_POSTGRES_PORT`, `TEMPLATE_DJANGO_PORT` or `TEMPLATE_FRONTEND_PORT`
to choose them. Temporary files, its own container, volume and image are removed on exit.
SQLite is only for fast validation; PostgreSQL is the application target.

For browser verification or debugging, retain the disposable project and services:

```sh
TEMPLATE_KEEP=1 just template-test compose
# PostgreSQL keeps running; cd to the printed path and run just up on the printed ports.
# Follow docs/verification.md; when finished, use the printed cleanup command.
```

CI uses the same validation recipes. Its workflow also works after generation, when it runs the
application's checks directly. It never pushes commits, tags or deployment branches.

## Structure and boundaries

- `core/`: Django user, admin, Ninja schemas/endpoints, native Tasks example, tests.
- `config/`: Django settings/URLs (Python templates until generation).
- `frontend/`: independent Vite application; `src/components/ui/` holds shadcn source.
- `docs/`, `domains/`, `ux/`, `decisions/`: engineering, domain, UX and architecture notes.
- `AGENTS.md`: concise agent workflow; `CLAUDE.md` points to the same instructions.
- `compose.yml`: development PostgreSQL only.
- `Dockerfile`: backend production/release image. WhiteNoise serves admin static files in release.

Paper is the visual design workspace. UI work is verified in the real application with agent-browser.
Playwright is not included; persistent tests can be added later for regression-critical flows.

Production frontend hosting, signup/recovery/verification UX and a durable Django Tasks backend
are deliberately deferred. ImmediateBackend runs synchronously; it is not a production queue.
No Supabase, Go, Celery, Redis or RabbitMQ is included. See [foundation decisions](decisions/001-foundation.md).

Based on [Jeff Triplett's Django starter](https://github.com/jefftriplett/django-startproject),
maintained by [Teo Ruiz](https://github.com/teoruiz).
