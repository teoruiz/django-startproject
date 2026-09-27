#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:-sqlite}
case "$mode" in sqlite|compose) ;; *) echo "Usage: $0 [sqlite|compose]"; exit 2 ;; esac
test ! -f "$source_dir/manage.py" || { echo "Run template-test in the template checkout."; exit 1; }
validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/django-template-test.XXXXXX")
project_dir="$validation_dir/project"
export COMPOSE_PROJECT_NAME="template-$(basename "$validation_dir" | tr '[:upper:].' '[:lower:]-')"
cleanup() {
    result=$?
    if [[ "$result" != 0 && "$mode" == compose && -f "$project_dir/.env" ]]; then
        (cd "$project_dir" && docker compose logs --tail=100) || true
    fi
    if [[ "${TEMPLATE_KEEP:-0}" == 1 ]]; then
        echo "Kept generated project: $project_dir"
        echo "Compose project: $COMPOSE_PROJECT_NAME"
        echo "Cleanup: cd '$project_dir' && COMPOSE_PROJECT_NAME='$COMPOSE_PROJECT_NAME' docker compose down --volumes --remove-orphans"
        echo "Remove images: docker image rm $COMPOSE_PROJECT_NAME-web $COMPOSE_PROJECT_NAME-frontend $COMPOSE_PROJECT_NAME-release"
        echo "Then remove '$validation_dir'."
        return
    fi
    if [[ "$mode" == compose && -f "$project_dir/.env" ]]; then
        (cd "$project_dir" && docker compose down --volumes --remove-orphans) || true
    fi
    if [[ "$mode" == compose ]]; then
        docker image rm "$COMPOSE_PROJECT_NAME-web" "$COMPOSE_PROJECT_NAME-frontend" "$COMPOSE_PROJECT_NAME-release" >/dev/null 2>&1 || true
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
        "*.tsbuildinfo", "staticfiles", "media", "compose.override.yml",
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
    cp .env-dist .env
    echo "COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME" >> .env
    just bootstrap
    just up -d --wait
    just manage check
    just manage makemigrations --check --dry-run
    just test
fi
just lint
just typecheck
just api-check
just frontend-build
if [[ "$mode" == compose ]]; then
    docker build --target release -t "$COMPOSE_PROJECT_NAME-release" .
fi
echo "Fresh generated project passed ($mode)."
