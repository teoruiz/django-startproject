# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Python Package Management with uv

Use uv exclusively for Python package management in this project.

### Package Management Commands

- All Python dependencies **must be installed, synchronized, and locked** using uv
- Never use pip, pip-tools, poetry, or conda directly for dependency management

Use these commands:

- Install dependencies: `uv add <package>`
- Remove dependencies: `uv remove <package>`
- Sync dependencies: `uv sync`

## Development Commands

This project uses `just` for task management. Key commands:

- `just bootstrap` - Initialize project with dependencies and environment
- `just up` - Start Django development server on http://localhost:8000/
- `just down` - Stop all containers
- `just test` - Run pytest tests
- `just lint` - Run pre-commit hooks (includes ruff, djlint, etc.)
- `just manage <command>` - Run Django management commands
- `just console` - Open bash shell in web container
- `just build` - Build Docker containers

## Architecture Overview

This is a Django 5.1 application with modern frontend tooling and API support:

**Core Structure:**
- `config/` - Django project configuration and settings
- `core/` - Main Django app with views, models, and API endpoints
- `frontend/` - Frontend assets including Tailwind CSS configuration
- `templates/` - Django HTML templates

**Key Technologies:**
- Django 5.2 with Python 3.13
- Django Ninja for API development (endpoints in `core/api.py`)
- Tailwind CSS v4 with CSS-first configuration and DaisyUI components
- PostgreSQL 17 database with Docker
- HTMX for dynamic interactions
- WhiteNoise for static file serving
- UV for dependency management

**API Development:**
- API endpoints are defined in `core/api.py` using Django Ninja
- Base API URL: `/api/` (configured in `core/urls.py`)
- Example endpoint: `/api/hello` returns "Hello world"

**Frontend Development:**
- Tailwind CSS v4 configuration in `frontend/css/source.css`
- Uses `@import "tailwindcss"` syntax (not `@tailwind` directives)
- DaisyUI components enabled via `@plugin "daisyui"`
- Dark mode support configured with `@variant dark` directive
- Configuration follows CSS-first approach with `@theme` directive
- Custom color palette using OKLCH color space

**Database:**
- PostgreSQL 17 with Docker
- Database URL: `postgres:///{{ project_name }}` (default)
- Migrations: `just manage migrate`

**Testing:**
- pytest with Django integration
- Configuration in `pyproject.toml`
- Test settings in `conftest.py`
- Run with: `just test`

**Environment:**
- Environment variables in `.env` file (created from `.env-dist`)
- Settings managed via `environs` library
- Docker Compose for development environment with file watching
- UV for Python dependency management

## Important Configuration Files

- `justfile` - Task runner configuration
- `pyproject.toml` - Python project configuration, pytest settings, ruff linting
- `compose.yml` - Docker Compose configuration
- `config/settings.py` - Django settings
- `frontend/css/source.css` - Tailwind CSS v4 configuration
- `.cursor/rules/tailwind-css-4.mdc` - Tailwind CSS v4 guidance for development

## Linting and Code Quality

- Ruff for Python linting and formatting
- djlint for Django template linting
- Pre-commit hooks configured
- Target Python version: 3.13
- Line length: 120 characters
