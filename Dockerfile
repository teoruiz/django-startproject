# syntax = docker/dockerfile:experimental
# Uses Docker BuildKit for improved caching and build performance

# ------------------------------------------------------------
# Stage 1: Base/builder layer - Setup Python environment
# ------------------------------------------------------------
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

# Configure environment variables
ENV UV_SYSTEM_PYTHON=1
ENV UV_LINK_MODE=copy

# Set working directory
WORKDIR /src/

# Install curl for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies using uv
# Mount only the necessary files (dependency definitions)
# This optimizes layer caching - changes to other files won't invalidate this layer
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync \
        --all-extras \
        --frozen \
        --compile \
        --no-install-project

# ------------------------------------------------------------
# Step 2: Development layer
# ------------------------------------------------------------

FROM builder AS dev

# Create non-root user for development
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} app && useradd -u ${UID} -g ${GID} -m app

# Install development dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --dev

# Create directories for named volumes with correct ownership
RUN mkdir -p /cache/uv /src/.venv /src/.django_tailwind_cli \
    && chown -R app:app /cache/uv /src

COPY --chown=app:app . /src/

WORKDIR /src/

# Place executables in the environment at the front of the path
ENV PATH="/src/.venv/bin:$PATH"

USER app

# Development server with hot reload
CMD ["/src/start-dev.sh"]

# ------------------------------------------------------------
# Stage 3: Release - Final production image
# ------------------------------------------------------------
FROM builder AS release

# Use SIGINT for stopping the container
# This allows for graceful shutdown and proper cleanup
STOPSIGNAL SIGINT

# Create non-root user for production (fixed UID for consistency)
RUN groupadd -g 1000 app && useradd -u 1000 -g 1000 -m app

ADD . /src/

# Copy the uv cache from builder stage to avoid re-downloading packages
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

# Download the TailwindCSS CLI
# Using SQLite memory database and dummy secret key during build
RUN DATABASE_URL=sqlite://:memory: SECRET_KEY=build-key uv run --frozen -m manage tailwind --skip-checks download_cli

# Build the TailwindCSS styles
RUN DATABASE_URL=sqlite://:memory: SECRET_KEY=build-key uv run --frozen -m manage tailwind --skip-checks build

# Collect static files for production serving
RUN DATABASE_URL=sqlite://:memory: SECRET_KEY=build-key uv run --frozen -m manage collectstatic --noinput --clear

# Set ownership and switch to non-root user
RUN chown -R app:app /src
USER app

# Default command runs Gunicorn WSGI server
# - Binds to all interfaces on port 8000
# - Uses 2 worker processes for handling requests
CMD ["/src/start-web.sh"]

# Worker stage
FROM release AS worker

HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/src/healthcheck-worker.sh"]

CMD ["/src/start-worker.sh"]

# Web stage (default)
FROM release AS web

HEALTHCHECK --interval=60s --timeout=10s --start-period=40s --retries=3 \
    CMD ["/src/healthcheck-web.sh"]

CMD ["/src/start-web.sh"]
