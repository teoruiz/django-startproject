set dotenv-load := false

@default:
    just --list

# Install locked dependencies, build development images and migrate PostgreSQL.
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    test -f manage.py || { echo "Generate a project first; see README.md."; exit 1; }
    test -f .env || cp .env-dist .env
    uv sync --locked
    pnpm --dir frontend install --frozen-lockfile
    docker compose build
    docker compose up -d --wait db
    just manage migrate --noinput

up *args:
    docker compose up {{args}}

down:
    docker compose down

build:
    docker compose build

manage *args:
    docker compose run --rm --no-deps web python manage.py {{args}}

console:
    docker compose run --rm --no-deps web bash

logs *args:
    docker compose logs {{args}}

test *args:
    docker compose run --rm --no-deps web pytest {{args}}

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
