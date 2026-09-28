# Production release

The `Dockerfile` builds one release image: Gunicorn/Django plus the built React SPA, served from one public origin.
The routing, caching and alternatives are recorded in [decision 003](../decisions/003-production-frontend-hosting.md).
No hosting vendor, infrastructure or deployment is configured; this document describes what a deployment must provide.

## Build and validate

```sh
docker build --target release -t my-product:VERSION .   # Node build stage + Python runtime
RELEASE_KEEP=1 just release-check my-product:VERSION     # validate that tag; keep it running for a browser check
just release-check                                        # or build a temporary image, validate it, remove it
```

`just release-check` runs the image with `DJANGO_DEBUG=false`, generated test-only secrets and a disposable
PostgreSQL 17 container on a private Docker network. It applies migrations and creates a validation account with
one-off containers, starts Gunicorn on a free `127.0.0.1` port (or `RELEASE_PORT`), and checks the following:

- The image's health check.
- SPA routing and its fallback limits, cache headers and compressed assets.
- Unfold admin and its static files.
- Secure cookies, allauth login/logout with CSRF, `/api/me` and the task example.
- The runtime contains no Node, pnpm, frontend sources or development packages.

It removes everything it created unless `RELEASE_KEEP=1`, which prints the URL, account and cleanup command.
CI runs it for generated projects. In the template checkout, `just template-test compose` runs it for a fresh project.

## Routing

| Path | Handler |
| --- | --- |
| `/api/auth/*` | allauth Headless (browser sessions, CSRF) |
| `/api/*` | Django Ninja |
| `/admin/*` | Unfold/Django admin |
| `/static/*` | admin and Django static files (collectstatic, manifest-hashed) |
| `/assets/*` | Vite's content-hashed JS/CSS, served as built |
| `/health/` | database readiness probe |
| other GET/HEAD navigations accepting HTML | `frontend/dist/index.html`; React Router renders the route |

Missing assets, static files and API endpoints return 404, never the SPA. So do the reserved `admin`, `api`,
`assets`, `health`, `media` and `static` prefixes, and requests that do not accept HTML. Other methods on SPA routes
return 405 (or 403 first if CSRF fails). Unknown client routes return 200 with the SPA, which shows its not-found screen.
Files placed in `frontend/public/` are served from the site root with a 60-second cache, since they are not hashed.

## Required configuration

| Variable | Production value |
| --- | --- |
| `DJANGO_DEBUG` | unset or `false` |
| `SECRET_KEY` | a long random secret from the platform's secret store; startup fails without it |
| `DATABASE_URL` | PostgreSQL connection URL, from the secret store |
| `ALLOWED_HOSTS` | the public hostname(s); keep `localhost` for the container `HEALTHCHECK`, which sends `Host: localhost` |
| `CSRF_TRUSTED_ORIGINS` | the public origin, e.g. `https://product.example`, unless `TRUST_X_FORWARDED_PROTO` is enabled |
| `TRUST_X_FORWARDED_PROTO` | `true` only behind a proxy that overwrites `X-Forwarded-Proto` (see below) |
| `TASKS_BACKEND` | defaults to ImmediateBackend (synchronous, non-durable); choose a durable backend separately |
| `MAILER_BACKEND`, `DEFAULT_FROM_EMAIL` | real email delivery, once product flows send email |

Session and CSRF cookies are `Secure` whenever DEBUG is off, so the site must be served over HTTPS.
Run `python manage.py check --deploy` against production settings and address its warnings deliberately.

## HTTPS and proxies

Terminate TLS at the platform's load balancer or reverse proxy, redirect HTTP to HTTPS there, and set HSTS there
once the domain is committed to HTTPS. Forward requests to port 8000 with the original `Host` header. Django does not
redirect to HTTPS itself: the container health check calls it over plain HTTP.

Django sees the proxy's plain-HTTP connection. Choose one way to make CSRF origin checks match the browser's HTTPS
origin:

- Set `CSRF_TRUSTED_ORIGINS=https://product.example`. This is safe with any proxy.
- Set `TRUST_X_FORWARDED_PROTO=true` so `request.is_secure()` reflects the client connection. Do this only if every
  request reaches Gunicorn through a proxy that removes client-supplied `X-Forwarded-Proto` headers and sets its own.
  Otherwise clients can spoof HTTPS.

`X-Forwarded-Host` and `X-Forwarded-For` are not trusted. Gunicorn trusts forwarded scheme headers only from
`127.0.0.1` by default (`FORWARDED_ALLOW_IPS`). Serving the frontend from a different origin than the API is
unsupported without further work; see [architecture](architecture.md#production).

## Release procedure

1. Build the image and run `just release-check IMAGE` (or an equivalent check in the deployment pipeline).
2. Run `python manage.py migrate --noinput` once, as a one-off container with the production environment. Web
   containers never migrate on startup. Make migrations backward-compatible with the running release.
3. Start or replace web containers (`start-web.sh`: Gunicorn on port 8000, two workers). Use `/health/` for readiness.

Each image contains only its own frontend build. Open tabs keep working with already loaded code and fetch the new
`index.html` on their next navigation or reload. A file first requested after a release that belongs to the previous
build, such as a lazily loaded chunk, returns 404. The current app has no lazy chunks, but code splitting would expose
this. A rolling deployment can briefly serve an entry page and its assets from different versions, so
it is not seamless. Retain previous builds' assets (e.g. an asset bucket/CDN) or use session affinity if that
matters. API changes must also tolerate clients still running the previous frontend.

## Remaining deployment responsibilities

The deployment still needs a hosting platform, TLS, secrets management, the managed PostgreSQL service and backups,
logging/monitoring, and the migration step in its pipeline. Also decide how many Gunicorn workers each replica runs.
Allauth rate limits use a process-local cache, so review them before running multiple replicas. A durable task
backend and worker, public signup/recovery UX with email delivery, and user-upload storage (`MEDIA_ROOT` is not
served in production) are separate decisions.
