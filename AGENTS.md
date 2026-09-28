# Working on the application

These instructions guide product development in the generated Django/React application.
Read [README.md](README.md) for setup and [architecture](docs/architecture.md) for system boundaries.
Keep this guide concise and update it as the product gains domain-specific conventions.

## Find the relevant code

- `config/`: Django settings, URLs and application entry points.
- `core/`: identity, admin, initial Ninja API, task example and backend tests.
- `frontend/src/`: React routes, API clients and components; `components/ui/` contains shadcn/ui.
- `domains/`, `ux/`, `decisions/`: domain rules, user flows and architecture decisions; `docs/` holds engineering guidance.

## Before implementation

- Inspect existing code and the relevant domain/UX notes before extending a feature.
- Make domain decisions explicit in `domains/` and material architecture choices in `decisions/` before implementation.
- Describe UX states, errors and acceptance criteria in `ux/` when practical. Paper is the visual design workspace;
  record relevant document/frame links there.
- Keep abstractions proportional to actual requirements. Extend established patterns and components.

## Local development and checks

- Use uv exclusively for Python and pnpm for frontend dependencies. Commit `uv.lock` and `frontend/pnpm-lock.yaml`;
  bootstrap consumes locks, and dependency upgrades are an explicit action. Versions and lint settings live in config.
- `just bootstrap` installs dependencies, starts PostgreSQL and migrates. `just up` runs Django and Vite on the host;
  `just backend` / `just frontend` run them separately. Compose is only for PostgreSQL; do not add development containers.
- Ctrl-C or `just stop` stops local servers; `just down` also stops PostgreSQL and retains its data.
- Configure ports and environment in `.env` using `.env-dist`; use `.venv/bin/python` as the editor interpreter.
- `just manage <command>` runs Django management commands; `just test` runs pytest against PostgreSQL.
- Run focused tests while iterating and `just check` before handing off application changes. It includes lint,
  Python/TypeScript checks, API contract checks, frontend build and tests. Report what ran and any remaining failures.
- Run `just release-check` after changing the Dockerfile, dependencies, settings, URL routing or static/frontend serving.
  It runs the release image with DEBUG=false against disposable PostgreSQL.

## Backend rules

- Django owns domain models, invariants, permissions, workflows and authorization. Use the ORM and Ninja.
  PostgreSQL is authoritative for development and production; SQLite is only for disposable validation.
- Read [backend conventions](docs/backend-conventions.md) before changing models, migrations or admin.
  Use `TimeStampedModel`, documented fields, explicit choices/relationships and Unfold admin classes/inlines.
- Allauth Headless owns authentication through browser sessions with CSRF. Scope queries and authorize domain actions
  in Django; authenticated users are not automatically authorized for every object. Never disable CSRF to fix a proxy.
- Use `django.tasks` for work. ImmediateBackend is synchronous and non-durable, for development/tests only.
  Add a durable backend only when a production workflow requires it; no django-q2, Celery, Redis or RabbitMQ.
- Supabase and Go are absent. Optional Supabase Realtime/Storage may later provide infrastructure; never add Supabase
  Auth, direct browser/database CRUD, Edge Functions or business authorization in RLS. Go is for independent services only.
- The release image serves Django and the built SPA from one origin ([decision 003](decisions/003-production-frontend-hosting.md),
  [production release](docs/deployment.md)). Keep the SPA fallback URL last; add new top-level backend prefixes to its
  reserved list. Hosting vendor and durable task execution remain deployment decisions; a passing check is not a deployment.

## Frontend and API workflow

- React/TypeScript/Vite is the product frontend. Use existing shadcn/ui and project/domain components before adding primitives.
  Use React Router for navigation and TanStack Query for server state. Django templates support admin/infrastructure pages.
- Ninja OpenAPI is the business contract; authentication types come from installed allauth's schema.
  Run `just api-generate` after contract changes and commit the generated types. Never hand-edit or duplicate those schemas.
- Use the existing openapi-fetch clients and relative `/api/...` URLs. Preserve session cookies and CSRF handling;
  frontend route guards are presentation, not authorization.
- Verify UI changes with agent-browser in the running application, including relevant routing, auth/API flows and console errors.
  Follow [browser verification](docs/verification.md). Playwright is not baseline tooling; persistent tests are reserved
  for important regression-critical flows.

## Template maintenance — only when `manage.py` is absent

- In the template checkout, the generated application is the artifact. Run `just template-test` against a fresh local
  generation; also run `just template-test compose` for PostgreSQL, Docker, release-image or development-server changes.
- Generate with Django's standard `startproject --template` command. Render only Python; preserve JS/TS/Just/Actions braces.
  The validation script filters local secrets/caches. Never validate only the template source tree.
