#!/usr/bin/env bash
# Run the release image in production mode (DEBUG=false) against disposable PostgreSQL on a private Docker
# network, then check its HTTP behavior and runtime contents. Without an argument it builds a temporary image;
# pass an existing tag to validate that image instead (it is never removed). Containers, network, secrets and a
# built image are removed on exit unless RELEASE_KEEP=1. RELEASE_PORT selects the host port (127.0.0.1 only).
set -euo pipefail
cd "$(dirname "$0")/.."
test -f manage.py || { echo "Run release-check in a generated project."; exit 1; }
project=$(basename "$PWD")
project=${project,,}
name="release-check-${project//[^a-z0-9_.-]/-}-$$"
image=${1:-}
built_image=""
if [[ -z "$image" ]]; then
    image=$name
    built_image=$name
fi
random() { uv run --no-project python -c 'import secrets; print(secrets.token_urlsafe(24))'; }
port=${RELEASE_PORT:-$(uv run --no-project python -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')}
email="Release-Check@Example.com"
password="check-only-$(random)"
env_file=$(mktemp)
cleanup() {
    status=$?
    if [[ $status != 0 ]]; then docker logs --tail 50 "$name-web" 2>&1 || true; fi
    if [[ "${RELEASE_KEEP:-0}" == 1 ]]; then
        echo "Release running at http://localhost:$port (image $image)."
        echo "Validation account: $email / $password"
        echo "Cleanup: docker rm -fv $name-web $name-db; docker network rm $name; rm -f $env_file${built_image:+; docker image rm $built_image}"
        return
    fi
    docker rm -fv "$name-web" "$name-db" >/dev/null 2>&1 || true
    docker network rm "$name" >/dev/null 2>&1 || true
    if [[ -n "$built_image" ]]; then docker image rm "$built_image" >/dev/null 2>&1 || true; fi
    rm -f "$env_file"
}
trap cleanup EXIT

if [[ -n "$built_image" ]]; then docker build --target release -t "$image" .; fi
[[ $(docker image inspect --format '{{.Config.Healthcheck.Test}}' "$image") == *healthcheck-web.sh* ]]

# The runtime image carries the built SPA but no Node toolchain, frontend sources or development dependencies.
docker run --rm --user root --entrypoint sh "$image" -euc '
    fail() { echo "Unexpected in runtime image: $1" >&2; exit 1; }
    for tool in node npm npx pnpm corepack vite; do if command -v "$tool" >/dev/null; then fail "$tool"; fi; done
    test -z "$(find / -xdev -name node_modules -print -quit)" || fail node_modules
    for path in frontend/src frontend/package.json .env; do if test -e "$path"; then fail "$path"; fi; done
    for module in pytest pytest_django model_bakery ruff basedpyright; do
        if python -c "import $module" 2>/dev/null; then fail "$module"; fi
    done
    test -f frontend/dist/index.html && ls frontend/dist/assets/*.js.gz >/dev/null
'
echo "Runtime image contains the frontend build and no Node or development tooling."

db_password=$(random)
cat > "$env_file" <<EOF
DJANGO_DEBUG=false
SECRET_KEY=release-check-only-$(random)
ALLOWED_HOSTS=localhost,127.0.0.1
DATABASE_URL=postgres://postgres:$db_password@$name-db:5432/app
TASKS_BACKEND=django.tasks.backends.immediate.ImmediateBackend
EOF
docker network create "$name" >/dev/null
docker run -d --name "$name-db" --network "$name" --tmpfs /var/lib/postgresql/data \
    -e POSTGRES_DB=app -e POSTGRES_PASSWORD="$db_password" postgres:17-bookworm >/dev/null
# TCP readiness excludes the entrypoint's temporary socket-only initialization server.
for attempt in $(seq 120); do
    docker exec "$name-db" pg_isready -q -h 127.0.0.1 -U postgres -d app && break
    [[ $attempt != 120 ]] || { echo "PostgreSQL did not start" >&2; exit 1; }
    sleep 0.5
done
run_once() { docker run --rm --network "$name" --env-file "$env_file" "$@"; }
# Migrations are an explicit release step; web containers never run them on start-up.
run_once "$image" python manage.py migrate --noinput
run_once -e DJANGO_SUPERUSER_PASSWORD="$password" "$image" \
    python manage.py createsuperuser --noinput --email "$email"
docker run -d --name "$name-web" --network "$name" --env-file "$env_file" -p "127.0.0.1:$port:8000" "$image" >/dev/null
for attempt in $(seq 120); do
    [[ $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/health/") == 200 ]] && break
    [[ $attempt != 120 ]] || { echo "Release web container did not become healthy" >&2; exit 1; }
    sleep 0.5
done
docker exec "$name-web" sh healthcheck-web.sh
uv run --locked python scripts/smoke.py "http://localhost:$port" "$email" "$password" --release
echo "Release image passed (DEBUG=false, PostgreSQL, gunicorn on 127.0.0.1:$port)."
