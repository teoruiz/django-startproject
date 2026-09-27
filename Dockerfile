# syntax=docker/dockerfile:1
FROM python:3.13-slim-bookworm AS base
COPY --from=ghcr.io/astral-sh/uv:0.10.6 /uv /uvx /bin/
ENV UV_PROJECT_ENVIRONMENT=/opt/venv UV_LINK_MODE=copy \
    PATH="/opt/venv/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev

FROM base AS dev
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked
RUN useradd --create-home app && chown -R app:app /app /opt/venv
COPY --chown=app:app . .
USER app
CMD ["sh", "start-dev.sh"]

FROM base AS release
COPY . .
RUN DATABASE_URL=sqlite://:memory: SECRET_KEY=build-only python manage.py collectstatic --noinput
RUN useradd --create-home app && chown -R app:app /app
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD ["sh", "healthcheck-web.sh"]
CMD ["sh", "start-web.sh"]
