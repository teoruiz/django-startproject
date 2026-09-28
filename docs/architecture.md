# Application architecture

```text
React + React Router + TanStack Query (Vite on the host, localhost:5173)
  /api proxy, session cookie + CSRF
Django (runserver on the host, localhost:8000)
  /api/auth/browser/v1/* -> allauth Headless
  /api/*                 -> Ninja + Django authorization
  /admin/                -> Unfold
  /health/               -> database readiness probe
PostgreSQL 17 (Docker Compose, 127.0.0.1:5432)
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

The Docker release stage is backend-only and installs no development dependencies. Static collection
builds admin assets; it does not bundle React. Migrations are an explicit release step. Production must
provide its own secrets, PostgreSQL, email, HTTPS/proxy settings, media storage and frontend routing.
`django-storages` is available for an eventual storage decision. Health checks query the database without
exposing credentials/errors. No production hosting provider is assumed.

## How the frontend reaches Django in production

In development, the browser loads `http://localhost:5173` and calls `/api/...` on that same origin.
Vite forwards those requests to Django on `127.0.0.1:${DJANGO_PORT}` (8000 by default). This lets the browser use Django's session
cookie without cross-origin requests. CSRF protection still applies to writes.

A production deployment can preserve that browser-facing arrangement:

```text
https://product.example/          -> built React files
https://product.example/api/...   -> Django (including allauth)
https://product.example/admin/... -> Django
https://product.example/static/... -> Django admin assets
```

The static files and Django may run on different infrastructure; a reverse proxy or CDN can route
the paths while exposing one origin to the browser. This example does not choose a hosting provider.
Vite's development proxy is not a production server, and the starter does not configure this routing.

Serving React at `https://app.example.com` and Django at `https://api.example.com` instead creates
two browser origins. The current client's `credentials: "same-origin"` and relative URLs would need
to change, alongside explicit credentialed CORS, trusted CSRF origins and cookie handling. Unrelated
sites may also face third-party-cookie restrictions. Merely setting ALLOWED_HOSTS does not configure
these things. Whichever deployment is chosen, HTTPS and Django's secure cookies remain required.

That is the deferred decision: where requests go and how the browser sends its session cookie.
There is no missing authentication service, and Django remains the authority for every request.

See [allauth's cross-origin guidance](https://docs.allauth.org/en/latest/headless/cors.html) when deploying across origins.
