# Browser verification

Use a disposable **generated** project with PostgreSQL: `TEMPLATE_KEEP=1 just template-test compose`.
It leaves PostgreSQL running and prints the project path, ports and a validation account. In that directory,
run `just up` (Django and Vite on the host) and open the printed Vite URL. In your own project, create an
account with `just manage createsuperuser` and use http://localhost:5173.
Use an isolated agent-browser session; do not save auth state in the repository.

```sh
agent-browser --session starter open http://localhost:5173   # or the printed FRONTEND_PORT
agent-browser --session starter snapshot -i
# Click Account, snapshot again, then fill Email and Password and submit.
agent-browser --session starter snapshot -i
agent-browser --session starter errors
agent-browser --session starter console
agent-browser --session starter screenshot /tmp/starter-account.png
```

Verify these acceptance criteria:

1. Home loads; Account navigation and direct `/account` navigation work.
2. Invalid credentials show an accessible error; no private data appears.
3. A valid login goes through `/api/auth/browser/v1/auth/login`.
4. `/api/me` returns the signed-in user's typed data, and the page renders their name/email.
5. Refresh preserves authentication. Unknown routes show the not-found screen.
6. Sign-out returns to the form; subsequent `/api/me` requests are unauthorized.
7. There are no unexpected console errors, failed asset requests or runtime exceptions.
   HTTP 401 for anonymous `/api/me` and successful allauth logout, and 400 for deliberately invalid
   credentials, are expected protocol responses.
8. Check a narrow viewport for overflow and usable form controls.

Close the browser session, press Ctrl-C in the `just up` terminal (or run `just stop`) and run the printed
disposable cleanup command when finished.

## Production image

For changes to the release image, settings, routing or static/frontend serving, repeat the checks above against the
running image. In a generated project, `RELEASE_KEEP=1 just release-check` leaves the image running with DEBUG=false and
disposable PostgreSQL, and prints its URL, a validation account and the cleanup command. (`TEMPLATE_KEEP=1 just
template-test compose` does the same for a fresh project.) Also verify:

1. Client-side navigation, and direct navigation and refresh on `/account` and an unknown route.
2. Login, `/api/me` rendering and logout on the same origin; session and CSRF cookies are `Secure`.
3. The task example from the signed-in page, e.g.
   `agent-browser eval 'fetch("/api/csrf").then(r => r.json()).then(({csrf_token}) => fetch("/api/tasks/welcome", {method: "POST", headers: {"X-CSRFToken": csrf_token}})).then(r => r.status)'`.
4. `/admin/` renders with its styles; no failed `/assets/` or `/static/` requests; no console or runtime errors.
Do not add Playwright dependencies just to run this manual verification. Persistent browser tests
are a separate product decision for important regression-critical flows.

## Frontend cache fixes validation record — 2026-09-29

- Fresh `just template-test` and `just template-test compose` generations passed: 55 pytest tests each,
  system checks, migrations, lint, Python/TypeScript checks, API contracts and frontend builds.
- A real Vite build with public SVGs, including a name resembling a hash, copied them unchanged and served them
  with `max-age=60, public`. Manifest-listed JS/CSS remained immutable. A missing manifest also kept assets mutable.
- The PostgreSQL release image passed its HTTP smoke checks, including `Vary: Accept` and `no-cache` on rejected
  GET/HEAD requests, followed by successful HTML navigation to the same URL.
- agent-browser verified the production image's authenticated account rendering, refresh, API/task calls,
  direct unknown-route navigation, styled admin and logout. No browser console or JavaScript errors were recorded.
  Extended direct-to-Gunicorn browsing also briefly showed an account-load error; retry recovered. The unchanged
  synchronous runner logged a worker timeout while waiting for HTTP request data, before Django handled a route.
  Proxy buffering and worker selection need separate production verification.

## Production frontend hosting validation record — 2026-09-28

Validated fresh artifacts generated from the local working template after adding the SPA to the release image:

- `just template-test`: SQLite path without a frontend build before checks/tests; checks, migrations/drift, 45 pytest
  tests (including 24 routing/fallback/method/cache-header cases), lint, basedpyright, TypeScript, contracts and build.
- `just template-test compose`: the existing host-development checks, then `just release-check`. It built the image
  and verified the runtime has no Node, pnpm, `node_modules`, frontend sources or dev packages. It ran the image with
  DEBUG=false and test-only secrets against disposable PostgreSQL 17, with migrations and the account created by
  one-off containers. The HTTP smoke passed: SPA routes, HEAD and 405, gzip immutable `/assets/` and admin `/static/`,
  404 for missing assets/static/API/media and non-HTML requests, `no-cache` entry page, `no-store` API, `Secure`
  cookies, login/CSRF, `/api/me`, the task example and logout. Its containers, network and image were removed.
- agent-browser against the running production image (Gunicorn, DEBUG=false, ImmediateBackend selected explicitly):
  home render, client-side navigation to Account, direct `/account` and refresh, an unknown route showing Page not
  found, invalid then valid login and `/api/me` rendering, refresh preserving the session, `Secure`/`HttpOnly`/`Lax`
  cookies, task enqueue from the page (200 with CSRF, 403 without), styled Unfold admin with 200 for all static
  requests, sign-out and 401 afterwards. No failed asset requests, console messages or page errors.
- Not validated: a TLS proxy, a real hosting platform, or behavior across a rolling deployment.

## Host development validation record — 2026-09-28

Validated fresh artifacts generated from the local working template after moving Django and Vite to the host:

- `just template-test`: SQLite path unchanged; checks, migrations/drift, 21 pytest tests, lint, basedpyright,
  TypeScript, contract check and Vite build passed.
- `just template-test compose` on free random ports: `just bootstrap` (locked installs, PostgreSQL on 127.0.0.1,
  local migrations), `just test` against PostgreSQL, the same checks, and the release-image build passed.
  Through the Vite proxy it verified allauth login with CSRF, `/api/me`, the task example, CSRF rejection and logout.
  Ctrl-C, a killed runserver and `just stop` each left no listening ports, processes or PID files;
  `just down` stopped the PostgreSQL container. Its container, volume and image were removed.
- `just stop` never signaled an unrelated process holding a recorded PID, kept unconfirmed records (reused PID,
  malformed, paused supervisor) with an error, removed dead records, and worked across time zones. Twenty
  `just up`/`just stop` cycles left no processes; three needed the SIGKILL fallback for a hung runserver reloader.
- agent-browser against `just up` in the retained project verified routing/not-found, direct `/account`,
  invalid and valid login, authenticated `/api/me` rendering, refresh, the CSRF-protected task enqueue,
  sign-out and API denial, and a 390px viewport without overflow. No browser runtime errors.
- The release image served health, admin HTML/static and allauth OpenAPI with DEBUG off and no dev dependencies.

## Foundation validation record — 2026-09-27

Validated fresh artifacts generated from the local working template:

- `just template-test`: install, checks, migrations/drift, 13 pytest tests, Ruff/ESLint/Prettier,
  basedpyright (zero errors/warnings), TypeScript, schema drift check and Vite production build passed.
- `just template-test compose`: the same checks passed with PostgreSQL 17, plus clean bootstrap,
  healthy Django/Vite services and backend release-image construction.
- The release image served database health, Unfold admin HTML/static and the allauth OpenAPI schema
  with DEBUG disabled and no pytest/development dependencies installed.
- agent-browser verified invalid/valid login, typed authenticated data rendering, refresh, logout
  and subsequent API denial, routing/not-found, 390px viewport without horizontal overflow,
  native task enqueueing and the Unfold user form. No browser runtime exceptions were recorded.
- Generation probes verified secret/cache exclusions, unchanged JSX/CI expressions, Django variable
  substitution. A deliberate contract change was rejected. Normal generation now uses Django's standard
  command; checkout filtering is internal to template validation.

These are local validation results, not evidence of a hosted deployment. Re-run the recipes after changes.
