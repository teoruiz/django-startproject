# Django and Vite run on the host; Docker Compose provides only development PostgreSQL.
# .env supplies ports and settings; variables already set in the environment take precedence.
set dotenv-load

export DJANGO_PORT := env("DJANGO_PORT", "8000")
export FRONTEND_PORT := env("FRONTEND_PORT", "5173")

@default:
    just --list

# Install locked dependencies, start PostgreSQL and apply migrations.
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    test -f manage.py || { echo "Generate a project first; see README.md."; exit 1; }
    test -f .env || cp .env-dist .env
    uv sync --locked
    pnpm --dir frontend install --frozen-lockfile
    docker compose up -d --wait db
    uv run --locked python manage.py migrate --noinput

# Run Django and Vite together; Ctrl-C (or either server exiting) stops both.
up: db (_serve "django" "vite")

# Run only Django on 127.0.0.1:DJANGO_PORT.
backend: db (_serve "django")

# Run only Vite on 127.0.0.1:FRONTEND_PORT, proxying /api to Django.
frontend: (_serve "vite")

# Stop local servers started by up, backend or frontend in another terminal.
stop:
    #!/usr/bin/env bash
    set -uo pipefail
    shopt -s nullglob
    # Remove records a dead supervisor never finished publishing (serve-PID.XXXXXXXX).
    for file in .dev/serve-*; do
        [[ $file == *.pid || $file == *.stop ]] && continue
        pid=${file#.dev/serve-}
        pid=${pid%%.*}
        case "$pid" in ''|*[!0-9]*) continue ;; esac
        kill -0 "$pid" 2>/dev/null || rm -f "$file"
    done
    files=(.dev/serve-*.pid)
    for file in "${files[@]}"; do touch "$file.stop"; done
    for _ in $(seq 100); do
        pending=()
        for file in "${files[@]}"; do
            if [[ ! -f "$file" ]]; then
                rm -f "$file.stop"
                continue
            fi
            # This is only a liveness probe, never an ownership check or a signal.
            # A live/reused PID or unreadable record must not be declared stale.
            pid=""
            IFS= read -r pid < "$file" || true
            case "$pid" in
                ''|*[!0-9]*|0|1) ;;
                *) if ! kill -0 "$pid" 2>/dev/null; then
                       rm -f "$file" "$file.stop"
                       continue
                   fi ;;
            esac
            pending+=("$file")
        done
        [[ ${#pending[@]} == 0 ]] && exit 0
        sleep 0.1
    done
    echo "Shutdown not confirmed; records retained: ${pending[*]}" >&2
    exit 1

# Stop local servers and the PostgreSQL container. The database volume is kept.
down: stop
    docker compose down

# Start development PostgreSQL on 127.0.0.1:POSTGRES_PORT.
db:
    docker compose up -d --wait db

db-logs *args:
    docker compose logs {{args}} db

manage *args:
    uv run --locked python manage.py {{args}}

test *args: db
    uv run --locked pytest {{args}}

lint:
    uv run --locked ruff check .
    uv run --locked ruff format --check .
    pnpm --dir frontend lint

format:
    uv run --locked ruff check --fix .
    uv run --locked ruff format .
    pnpm --dir frontend format

typecheck:
    uv run --locked basedpyright
    pnpm --dir frontend typecheck

# Vite production build in frontend/dist; the release image builds its own copy.
frontend-build:
    pnpm --dir frontend build

# Schema export is database-independent; no application server is needed.
api-generate:
    uv run --locked python manage.py export_api
    pnpm --dir frontend api:generate

api-check:
    uv run --locked python manage.py export_api
    pnpm --dir frontend api:check

check: lint typecheck api-check frontend-build test

# Build the release image (or validate an existing tag) and run it with DEBUG=false against disposable PostgreSQL.
release-check image="":
    bash scripts/release-check.sh {{image}}

# Explicit upgrades only; bootstrap never changes locks.
upgrade:
    uv lock --upgrade
    uv sync --locked
    pnpm --dir frontend update

# In the template checkout, generate and validate a disposable artifact.
template-test mode="sqlite":
    bash scripts/template-test.sh {{mode}}

# Supervise host servers: prefixed logs; stop every server when one exits, on Ctrl-C or `just stop`.
# Each server runs in its own process group so its children (autoreloader, esbuild) stop too.
_serve +servers:
    #!/usr/bin/env bash
    set -uo pipefail
    set -m
    mkdir -p .dev
    # A new control path prevents old requests from reaching a later owner of this PID.
    record_tmp=$(mktemp ".dev/serve-$$.XXXXXXXX") || exit 1
    pidfile="$record_tmp.pid"
    pids=()
    color=()
    if [[ -t 1 ]]; then export FORCE_COLOR=1; color=(--force-color); fi
    shutdown() {
        trap '' INT TERM
        for pid in "${pids[@]}"; do kill -TERM -- "-$pid" 2>/dev/null; done
        # uv forwards TERM, so runserver's reloader gets it twice and can occasionally hang; escalate after 5s.
        for _ in $(seq 50); do
            alive=0
            for pid in "${pids[@]}"; do kill -0 -- "-$pid" 2>/dev/null && alive=1; done
            [[ $alive == 0 ]] && break
            sleep 0.1
        done
        for pid in "${pids[@]}"; do kill -KILL -- "-$pid" 2>/dev/null; done
        wait
        rm -f "$record_tmp" "$pidfile" "$pidfile.stop"
        exit "$1"
    }
    trap 'shutdown 0' INT TERM
    # Publish the complete record atomically so stop never reads a partial one.
    printf '%s\n' "$$" > "$record_tmp"
    mv "$record_tmp" "$pidfile"
    for server in {{servers}}; do
        case $server in
            django) command=(uv run --locked python manage.py runserver ${color[@]+"${color[@]}"} "127.0.0.1:$DJANGO_PORT") ;;
            vite) command=(pnpm --dir frontend dev) ;;
        esac
        (
            "${command[@]}" </dev/null 2>&1 | while IFS= read -r line; do printf '%-6s | %s\n' "$server" "$line"; done
        ) &
        pids+=("$!")
    done
    while :; do
        if [[ -f "$pidfile.stop" ]]; then
            rm -f "$pidfile.stop"
            shutdown 0
        fi
        for pid in "${pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                status=$?
                echo "A server exited (status $status); stopping the others." >&2
                shutdown "$(( status == 0 ? 1 : status ))"
            fi
        done
        sleep 0.5 & wait $!
    done
