# Host development servers

Accepted: the one development workflow runs Django (`uv run`) and Vite (`pnpm`) directly on the host.
Docker Compose runs only PostgreSQL 17, published on `127.0.0.1:${POSTGRES_PORT}`, with a named data volume.
There is no parallel full-Docker development setup and no development image.

Reasons: host processes give native file watching, editor/debugger access to `.venv/bin/python`, direct
`uv`/`pnpm` use and faster restarts, while Compose still pins the authoritative database version.
PostgreSQL remains the development and test database; SQLite is only for disposable template validation.

`.env` holds `POSTGRES_PORT`, `DJANGO_PORT` and `FRONTEND_PORT`; `DATABASE_URL` and `CSRF_TRUSTED_ORIGINS`
interpolate them. Just, Compose and python-dotenv read the same file, and process environment wins in all three.
Both servers bind to 127.0.0.1. Vite proxies relative `/api` to Django without changing the Host header, so the
browser keeps one origin and allauth Headless sessions and Django CSRF behave as in a same-origin deployment.

`just up` supervises both servers with Bash only: each runs in its own process group with prefixed output.
Ctrl-C, `just stop` or either server exiting terminates both groups, including runserver's autoreloader child.
`just stop` writes a shutdown request beside each supervisor's record in `.dev/`. The supervisor
acknowledges by removing the request, then shuts down its child process groups and removes its record.
There is no wall-clock identity comparison, and stop never sends a signal to a PID read from disk.
It uses `kill -0` only to discard records whose recorded PID no longer exists. Unanswered requests with
live PIDs (including reused PIDs) or malformed records time out with an error and remain available for
inspection. A timeout cannot prove that a supervisor is dead: it may be paused or busy. This prevents
both unrelated process termination and silent loss of a live supervisor's record.
The supervisor sends SIGTERM to its own child process groups and SIGKILL to any still alive after 5 seconds:
`uv run` forwards SIGTERM, so runserver's autoreloader receives it twice and can occasionally hang.
`just down` also stops the PostgreSQL container and keeps its volume.
No process manager dependency (honcho, overmind, concurrently) is added.

The `Dockerfile` is the production/release image only (see 003). `just release-check` validates it, and
`just template-test compose` runs that check for a fresh generated project.
