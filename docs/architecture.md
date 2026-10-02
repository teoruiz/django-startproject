# Application architecture

```text
Development: React + React Router + TanStack Query (Vite on the host, localhost:5173)
  /api proxy, session cookie + CSRF
Django (runserver on the host, localhost:8000)
  /api/auth/browser/v1/* -> allauth Headless
  /api/*                 -> Ninja + Django authorization
  /admin/                -> Unfold
  /health/               -> database readiness probe
PostgreSQL 17 (Docker Compose, 127.0.0.1:5432)

Production: one release image and origin (Gunicorn + Django + WhiteNoise)
  /api/*, /admin/*, /health/ -> Django, as above
  /static/*, /assets/*       -> WhiteNoise (admin static, content-hashed Vite build)
  other HTML navigations     -> the SPA's index.html
```

Django owns business rules and authorization. Authentication is not sufficient authorization:
new domain endpoints must check the actor's permission against the relevant object and scope
ORM queries appropriately. `/api/me` always uses the session user; a client cannot select another user.
Ninja defaults to session authentication; explicitly public routes opt out individually.
Session-authenticated writes enforce Django CSRF checks. Never disable CSRF to fix a proxy issue.

Allauth handles email/password login and session lifecycle. A database constraint enforces
case-insensitive uniqueness of the login email, including accounts created through admin.
Every save stores the whole email in lowercase, because allauth matches login emails in lowercase. The React client retrieves a fresh CSRF
token before writes because login rotates the secret. Cookies are HttpOnly for the session, SameSite=Lax,
and Secure outside DEBUG. Vite preserves the browser Host header; development trusted origins are
explicitly listed in `.env-dist`. No wildcard CORS, localStorage tokens or custom password endpoint exists.

The starter supports administrator-created accounts: create an administrator with
`just manage createsuperuser`, then create ordinary users through Django admin. Those users can
sign in and out through React. They cannot yet register themselves, reset a forgotten password or
verify an email address through the frontend. "Provisioned" simply means created ahead of time;
it does not mean an external identity service or a special account type.

Public signup is disabled via `core.auth.AccountAdapter`. Email verification is off for these accounts. Before opening registration, design and implement signup, verification, account recovery,
email delivery and abuse handling together. Headless-only mode removes allauth's HTML account views.
Django's own admin still uses server-rendered templates and its usual staff login. The starter's
allauth rate limits use Django's process-local cache; revisit shared rate limiting for multiple replicas.

Django 6.1 mail configuration uses `MAILERS`; tests override it with the in-memory backend.
Python checks use basedpyright with current django-stubs (including native Tasks). One narrow
Unfold/Django admin mixin-signature suppression is documented at the class declaration.

Business types come from Ninja OpenAPI; authentication types come from the installed allauth schema.
`export_api` exports both offline through the public schema view/API. `openapi-typescript` generates
`frontend/src/lib/{api,auth}.d.ts`; `openapi-fetch` supplies the typed transport. `just api-check` regenerates
in memory and compares content, without relying on Git or silently rewriting tracked files.

`core.tasks.welcome_message.enqueue(...)` demonstrates Django's Tasks API. Its authenticated, CSRF-protected
`POST /api/tasks/welcome` returns a task ID without assuming durable result storage. Tests prove execution
with ImmediateBackend. Production background delivery, retries and workers are deliberately unconfigured.

The Docker release image builds the React SPA in a Node stage and copies only its static output into the Python
runtime, which has no Node or development dependencies. Static collection builds admin assets. Migrations are an
explicit release step. Production must provide secrets, PostgreSQL, email, HTTPS/proxy settings and media storage.
`django-storages` is available for an eventual storage decision. Health checks query the database without
exposing credentials/errors. No production hosting provider is assumed.

## Production

In development, the browser loads `http://localhost:5173` and calls `/api/...` on that same origin.
Vite forwards those requests to Django on `127.0.0.1:${DJANGO_PORT}` (8000 by default). This lets the browser use
Django's session cookie without cross-origin requests. CSRF protection still applies to writes.

Production keeps that browser-facing arrangement without Vite: the release image serves everything from one origin.
WhiteNoise serves the Vite build's content-hashed `/assets/` (cached as immutable) and admin `/static/`.
Django serves `/api/`, `/admin/` and `/health/`. A catch-all view returns the SPA's `index.html` (`no-cache`) for other
browser navigations, so direct navigation and refresh work. Missing assets and API paths still return errors.
See [decision 003](../decisions/003-production-frontend-hosting.md) for the routing rules and
[the production release guide](deployment.md) for configuration, HTTPS/proxy handling and release behavior.

Serving React at `https://app.example.com` and Django at `https://api.example.com` instead creates
two browser origins. The current client's `credentials: "same-origin"` and relative URLs would need
to change, alongside explicit credentialed CORS, trusted CSRF origins and cookie handling. Unrelated
sites may also face third-party-cookie restrictions. Merely setting ALLOWED_HOSTS does not configure
these things. See [allauth's cross-origin guidance](https://docs.allauth.org/en/latest/headless/cors.html)
before choosing that. Whichever deployment is chosen, HTTPS and Django's secure cookies remain required.
