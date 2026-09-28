# Production frontend hosting

Accepted: one release image contains Django and the built React SPA and serves them from one public origin.
The Dockerfile builds the frontend in a Node stage from the committed pnpm lockfile, then copies only `frontend/dist`
into the Python runtime image. The runtime image has no Node, pnpm, Vite server or frontend development dependencies.
Development is unchanged: Django and Vite run on the host, and Vite proxies `/api` (see 002).

Routing, in precedence order:

| Path | Served by |
| --- | --- |
| `/static/*` | WhiteNoise: collectstatic output (admin), manifest-hashed and compressed |
| `/assets/*` and other files at the root of `frontend/dist` | WhiteNoise, with `WHITENOISE_ROOT` set to the Vite build |
| `/api/*`, `/admin/*`, `/health/` | Django URLs: Ninja, allauth Headless, Unfold admin and the health probe |
| Any other path, for a GET/HEAD request that accepts `text/html` | `core.views.frontend`: `frontend/dist/index.html` |

Missing files under `/assets/` or `/static/`, missing `/api/` endpoints and the reserved `admin`, `api`, `assets`,
`health`, `media` and `static` prefixes never fall back to the SPA. Neither do other methods (405) or requests that do
not accept HTML (404), such as scripts, images and API clients. React Router renders unknown client routes, including
its not-found screen. Because the server cannot know client routes, those responses are HTTP 200.

Caching: Vite content-hashes every file it emits under `assets/`, so WhiteNoise marks them immutable for ten years.
The Vite build is served as-is instead of through Django staticfiles, which would hash and rewrite it a second time.
The entry page and other HTML are `Cache-Control: no-cache`, so every navigation revalidates and picks up a new release.
`/api/` responses without explicit caching get Django's never-cache headers, keeping session data out of shared caches.
Release images precompress the build with WhiteNoise, and collectstatic still compresses admin assets.

Each image contains only its own build's assets. A tab opened before a release keeps running its already loaded
code, but any file it requests later from the previous build (such as a lazily loaded chunk) returns 404
until the user reloads. During a rolling deployment that mixes versions, an entry page from one version can request
assets from a replica running the other. Seamless rolling deployments would therefore need old assets retained
(for example, an asset CDN/bucket or session affinity). This starter does not claim or validate that.

Alternatives rejected: a separate static host or CDN with path routing (a second deployable and routing layer to keep
consistent), a separate frontend origin (credentialed CORS, cross-site cookies and CSRF changes), an SSR framework, and
adding the Vite build to `STATICFILES_DIRS` (double hashing and a different URL prefix). These can be revisited when
traffic or product needs justify them. HTTPS termination, the hosting vendor and infrastructure are deployment
decisions; durable tasks, public signup/recovery UX and user-upload storage remain separate decisions.
