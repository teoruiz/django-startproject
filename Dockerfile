# syntax=docker/dockerfile:1
# Build the React SPA from the committed lockfile. Only its static output reaches the release image.
FROM node:22-bookworm-slim AS frontend
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN corepack enable
WORKDIR /frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm build

FROM python:3.13-slim-bookworm AS base
COPY --from=ghcr.io/astral-sh/uv:0.10.6 /uv /uvx /bin/
ENV UV_PROJECT_ENVIRONMENT=/opt/venv UV_LINK_MODE=copy \
    PATH="/opt/venv/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev

# Django, Gunicorn and the built SPA on one origin; see decisions/003-production-frontend-hosting.md.
FROM base AS release
COPY --exclude=frontend . .
COPY --from=frontend /frontend/dist frontend/dist
# WhiteNoise serves the Vite build directly (not via collectstatic); its manifest identifies versioned assets.
RUN python -m whitenoise.compress --quiet frontend/dist \
    && DATABASE_URL=sqlite://:memory: SECRET_KEY=build-only python manage.py collectstatic --noinput
RUN useradd --create-home app && chown -R app:app /app
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD ["sh", "healthcheck-web.sh"]
CMD ["sh", "start-web.sh"]
