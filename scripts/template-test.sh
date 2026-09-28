#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:-sqlite}
case "$mode" in sqlite|compose) ;; *) echo "Usage: $0 [sqlite|compose]"; exit 2 ;; esac
test ! -f "$source_dir/manage.py" || { echo "Run template-test in the template checkout."; exit 1; }
validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/django-template-test.XXXXXX")
project_dir="$validation_dir/project"
export COMPOSE_PROJECT_NAME="template-$(basename "$validation_dir" | tr '[:upper:].' '[:lower:]-')"
server_pgid=""
stop_servers() {
    if [[ -n "$server_pgid" ]]; then
        kill -TERM -- "-$server_pgid" 2>/dev/null || true
        wait "$server_pgid" 2>/dev/null || true
        server_pgid=""
    fi
    if [[ -d "$project_dir/.dev" ]]; then
        (cd "$project_dir" && just stop) || true
    fi
}
cleanup() {
    result=$?
    stop_servers
    if [[ "$result" != 0 && "$mode" == compose && -f "$project_dir/.env" ]]; then
        (cd "$project_dir" && docker compose logs --tail=100) || true
    fi
    if [[ "${TEMPLATE_KEEP:-0}" == 1 ]]; then
        echo "Kept generated project: $project_dir"
        if [[ "$mode" == compose ]]; then
            echo "PostgreSQL is running (compose project $COMPOSE_PROJECT_NAME, port ${POSTGRES_PORT:-})."
            echo "Run servers: cd '$project_dir' && just up   # http://localhost:${FRONTEND_PORT:-}"
            echo "Validation account: smoke@example.com / smoke-password-123"
            echo "Cleanup: cd '$project_dir' && just stop; docker compose down --volumes --remove-orphans"
            echo "Remove image: docker image rm $COMPOSE_PROJECT_NAME-release"
        fi
        echo "Then remove '$validation_dir'."
        return
    fi
    if [[ "$mode" == compose && -f "$project_dir/.env" ]]; then
        (cd "$project_dir" && docker compose down --volumes --remove-orphans) || true
        docker image rm "$COMPOSE_PROJECT_NAME-release" >/dev/null 2>&1 || true
    fi
    rm -rf "$validation_dir"
}
trap cleanup EXIT
# Only validation needs a sanitized snapshot of a potentially dirty local checkout.
# Normal project creation uses django-admin startproject directly (see README).
uv run --no-project python - "$source_dir" "$validation_dir/template" <<'PYTHON'
import shutil
import sys

shutil.copytree(
    sys.argv[1], sys.argv[2],
    ignore=shutil.ignore_patterns(
        ".git", ".venv", ".env", ".env.*", "__pycache__", "*.pyc",
        "node_modules", ".pnpm-store", "dist", ".schema", ".pytest_cache",
        ".ruff_cache", ".agents", ".codex", "*.sqlite3", "*.sqlite3-*",
        "*.tsbuildinfo", "staticfiles", "media", "compose.override.yml", ".dev",
    ),
)
PYTHON
uv run --no-project --with django==6.1.1 django-admin startproject \
    --template="$validation_dir/template" --extension=py --exclude=.git \
    validation_project "$project_dir"
cd "$project_dir"
test -f .github/workflows/actions.yml
test ! -d .git
test ! -d frontend/node_modules
test ! -f frontend/Dockerfile

free_port() {
    uv run --no-project python -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'
}
port_closed() { ! (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
wait_for() {  # URL, expected status
    for _ in $(seq 120); do
        [[ $(curl -s -o /dev/null -w '%{http_code}' "$1") == "$2" ]] && return 0
        sleep 0.5
    done
    echo "Timed out waiting for $1 to return $2" >&2
    return 1
}
wait_exit() {  # PID; succeeds when the process exits within 20 seconds
    for _ in $(seq 80); do kill -0 "$1" 2>/dev/null || return 0; sleep 0.25; done
    echo "Process $1 did not exit" >&2
    return 1
}
assert_stopped() {
    port_closed "$DJANGO_PORT" || { echo "Django still listening on $DJANGO_PORT" >&2; exit 1; }
    port_closed "$FRONTEND_PORT" || { echo "Vite still listening on $FRONTEND_PORT" >&2; exit 1; }
    if compgen -G ".dev/serve-*.pid" >/dev/null; then echo "Stale server PID files" >&2; exit 1; fi
}
# Start a command in its own process group, like a terminal foreground job.
start_group() { set -m; "$@" >>"$validation_dir/servers.log" 2>&1 & server_pgid=$!; set +m; }
# Exercise the browser path: Vite proxy, allauth Headless session, CSRF, Ninja and the task example.
proxy_smoke() {
    uv run --locked python - "http://localhost:$FRONTEND_PORT" <<'PYTHON'
import sys

import httpx

with httpx.Client(base_url=sys.argv[1]) as client:
    assert client.get("/").status_code == 200
    assert client.get("/api/me").status_code == 401
    assert client.get("/api/auth/browser/v1/config").status_code == 200
    login = {"email": "Smoke@Example.com", "password": "smoke-password-123"}
    assert client.post("/api/auth/browser/v1/auth/login", json=login).status_code == 403  # no CSRF token
    token = client.get("/api/csrf").json()["csrf_token"]
    response = client.post("/api/auth/browser/v1/auth/login", json=login, headers={"X-CSRFToken": token})
    assert response.status_code == 200, response.text
    assert client.get("/api/me").json()["email"] == "smoke@example.com"
    assert client.post("/api/tasks/welcome").status_code == 403  # rotated CSRF secret required
    token = client.get("/api/csrf").json()["csrf_token"]
    task = client.post("/api/tasks/welcome", headers={"X-CSRFToken": token})
    assert task.status_code == 200 and task.json()["task_id"], task.text
    logout = client.delete("/api/auth/browser/v1/auth/session", headers={"X-CSRFToken": token})
    assert logout.status_code == 401
    assert client.get("/api/me").status_code == 401
print("Proxy, session, CSRF and task checks passed.")
PYTHON
}

if [[ "$mode" == sqlite ]]; then
    export DATABASE_URL="sqlite:///$project_dir/validation.sqlite3"
    export DJANGO_DEBUG=true
    uv sync --locked
    uv run --locked python manage.py check
    uv run --locked python manage.py migrate --noinput
    uv run --locked python manage.py makemigrations --check --dry-run
    uv run --locked pytest
    pnpm --dir frontend install --frozen-lockfile
else
    # Free ports by default so validation never collides with a developer's services.
    export POSTGRES_PORT=${TEMPLATE_POSTGRES_PORT:-$(free_port)}
    export DJANGO_PORT=${TEMPLATE_DJANGO_PORT:-$(free_port)}
    export FRONTEND_PORT=${TEMPLATE_FRONTEND_PORT:-$(free_port)}
    echo "Ports: PostgreSQL $POSTGRES_PORT, Django $DJANGO_PORT, Vite $FRONTEND_PORT"
    sed -e "s/^POSTGRES_PORT=.*/POSTGRES_PORT=$POSTGRES_PORT/" \
        -e "s/^DJANGO_PORT=.*/DJANGO_PORT=$DJANGO_PORT/" \
        -e "s/^FRONTEND_PORT=.*/FRONTEND_PORT=$FRONTEND_PORT/" .env-dist > .env
    echo "COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME" >> .env
    just bootstrap
    [[ $(docker compose port db 5432) == "127.0.0.1:$POSTGRES_PORT" ]]
    just manage check
    just manage makemigrations --check --dry-run
    just test
    DJANGO_SUPERUSER_PASSWORD=smoke-password-123 \
        just manage createsuperuser --noinput --email Smoke@Example.com

    # Ctrl-C stops both servers, including Django's autoreloader child.
    start_group just up
    wait_for "http://127.0.0.1:$DJANGO_PORT/health/" 200
    wait_for "http://127.0.0.1:$FRONTEND_PORT/" 200
    proxy_smoke
    kill -INT -- "-$server_pgid"
    wait_exit "$server_pgid"
    server_pgid=""
    assert_stopped
    echo "Ctrl-C stopped both servers."

    # A failing server stops the other and makes `just up` fail.
    start_group just up
    up_pid=$server_pgid
    wait_for "http://127.0.0.1:$FRONTEND_PORT/" 200
    wait_for "http://127.0.0.1:$DJANGO_PORT/health/" 200
    pkill -KILL -f "manage.py runserver.*127.0.0.1:$DJANGO_PORT"
    wait_exit "$up_pid"
    if wait "$up_pid"; then echo "just up succeeded after a server failure" >&2; exit 1; fi
    server_pgid=""
    assert_stopped
    echo "A failed server stopped the other."

    # Independently started servers, stopped from another terminal.
    start_group just backend
    backend_pid=$server_pgid
    start_group just frontend
    frontend_pid=$server_pgid
    server_pgid=""
    wait_for "http://127.0.0.1:$DJANGO_PORT/health/" 200
    wait_for "http://localhost:$FRONTEND_PORT/api/me" 401
    just stop
    wait_exit "$backend_pid"
    wait_exit "$frontend_pid"
    assert_stopped
    echo "just stop stopped independently started servers."
fi
just lint
just typecheck
just api-check
just frontend-build
if [[ "$mode" == compose ]]; then
    docker build --target release -t "$COMPOSE_PROJECT_NAME-release" .
    if [[ "${TEMPLATE_KEEP:-0}" != 1 ]]; then
        just down
        [[ -z $(docker compose ps -q db) ]] || { echo "PostgreSQL still running after just down" >&2; exit 1; }
    fi
fi
echo "Fresh generated project passed ($mode)."
