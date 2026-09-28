# Working in this repository

- This is a Django startproject template. The generated application is the artifact. Inspect first and validate changes
  with `just template-test`; use `just template-test compose` for PostgreSQL/Docker changes. Generated apps use `just check`.
- Development runs Django and Vite on the host (`just up`, or `just backend`/`just frontend`); Docker Compose runs only
  PostgreSQL. Stop servers with Ctrl-C or `just stop`; `just down` also stops PostgreSQL. Never add development containers.
- Django owns domain models, invariants, permissions, workflows and authorization. PostgreSQL is authoritative;
  SQLite is only for disposable validation. Use Django ORM, Ninja and allauth Headless browser sessions with CSRF.
- Write domain decisions in `domains/` and material architecture choices in `decisions/` before implementation.
  Describe UX behavior in `ux/` before implementation when practical. Paper is the intended visual design workspace.
- React/TypeScript/Vite is the product frontend. Use existing shadcn/ui and project/domain components; extend them
  rather than inventing arbitrary primitives. Ninja OpenAPI is the business contract: run `just api-generate` after
  changing schemas and commit generated types. Do not hand-edit or duplicate them.
- Use `django.tasks` for work. ImmediateBackend is for development/tests; no django-q2, Celery, Redis or RabbitMQ.
  Add a durable task backend only when a real production workflow requires it.
- Use uv exclusively for Python and pnpm for frontend dependencies. Commit both lockfiles. Run lint, tests and
  type checks appropriate to the change. Bootstrap consumes locks; upgrading dependencies is an explicit action.
- Models use TimeStampedModel, documented fields, explicit relationships/choices and meaningful string representations.
  Admin classes and inlines use Unfold. Keep abstractions proportional to actual product requirements.
- Verify UI changes in the running generated application with agent-browser, including relevant auth and API flows.
  Playwright is not in the baseline. Persistent Playwright tests require important regression-critical flows.
- Supabase and Go are absent. Optional Supabase Realtime/Storage may be infrastructure later; Django still owns
  authentication and authorization. Never introduce direct browser/database CRUD, Supabase Auth or Edge Functions.
- Template rendering is limited to Python. Preserve JS/TS/Just/GitHub Actions braces. Use Django's standard `startproject --template` command. Template validation filters local secrets/caches
  internally. Never validate only the template source tree.
