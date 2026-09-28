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
    for file in .dev/serve-*.pid; do
        kill -TERM "$(<"$file")" 2>/dev/null || rm -f "$file"
    done
    for _ in $(seq 100); do
        files=(.dev/serve-*.pid)
        [[ ${#files[@]} == 0 ]] && exit 0
        sleep 0.1
    done
    echo "Local servers did not stop: ${files[*]}" >&2
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
    pidfile=".dev/serve-$$.pid"
    pids=()
    color=()
    if [[ -t 1 ]]; then export FORCE_COLOR=1; color=(--force-color); fi
    shutdown() {
        trap '' INT TERM
        for pid in "${pids[@]}"; do kill -TERM -- "-$pid" 2>/dev/null; done
        wait
        rm -f "$pidfile"
        exit "$1"
    }
    trap 'shutdown 0' INT TERM
    echo $$ > "$pidfile"
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
