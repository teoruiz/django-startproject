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
- Django 6.0 with Python 3.13
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

**Database:**
- PostgreSQL 17 with Docker
- Database URL: `postgres:///rufisocios` (default)
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

## Django Model Patterns

Follow these patterns when creating Django models:

**Base Model:**
- Always use `TimeStampedModel` from `django_extensions.db.models` as the base class instead of `models.Model`
- This automatically provides `created` and `modified` timestamp fields

**Model Structure:**
- Define `TextChoices` classes inside the model for status and type fields
- Use descriptive choice values with proper labels (e.g., `DRAFT = "draft", "Draft"`)
- Place all choice classes at the top of the model definition

**Field Patterns:**
- Use `CharField` with `choices` parameter for status and type fields
- Set sensible `default` values for choice fields
- Use `TextField` for longer text content with descriptive `help_text`
- Use `ArrayField` from `django.contrib.postgres.fields` for lists
- Set `blank=True, default=list` for ArrayFields to avoid nullable arrays
- Use `ForeignKey` with `on_delete=models.SET_NULL` for optional relationships
- Include `null=True, blank=True` for optional foreign keys
- Always set a descriptive `related_name` for foreign keys

**Field Documentation:**
- Always include `help_text` for fields to document their purpose
- Use clear, descriptive field names that explain their content

**Meta Options:**
- Define `Meta` class with:
  - `ordering` - typically `["-created"]` for newest first
  - `verbose_name` and `verbose_name_plural`

**Methods:**
- Implement `__str__()` to return a meaningful string representation
- Use `@property` decorators for computed fields that aggregate model data
- Return dictionaries from properties when aggregating multiple related fields

**Example Model Structure:**
```python
from django.db import models
from django.contrib.postgres.fields import ArrayField
from django_extensions.db.models import TimeStampedModel


class MyModel(TimeStampedModel):
    class StatusChoices(models.TextChoices):
        DRAFT = "draft", "Draft"
        PUBLISHED = "published", "Published"

    title = models.CharField(max_length=200)
    status = models.CharField(
        max_length=20,
        choices=StatusChoices.choices,
        default=StatusChoices.DRAFT
    )
    description = models.TextField(
        blank=True,
        help_text="Detailed description of the item"
    )
    tags = ArrayField(
        models.CharField(max_length=50),
        blank=True,
        default=list,
        help_text="List of tags"
    )
    parent = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        related_name="children",
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ["-created"]
        verbose_name = "My Model"
        verbose_name_plural = "My Models"

    def __str__(self):
        return f"{self.title} ({self.status})"

    @property
    def metadata(self):
        """Returns complete metadata as a dictionary"""
        return {
            "timestamp": self.created,
            "title": self.title,
            "status": self.status,
        }
```

## Linting and Code Quality

- Ruff for Python linting and formatting
- djlint for Django template linting
- Pre-commit hooks configured
- Target Python version: 3.13
- Line length: 120 characters

## Django Admin with Unfold

This project uses **Django Unfold** for a modern admin interface.

**Setup:**
- Django Unfold is already installed and configured in `INSTALLED_APPS`
- "unfold" must be placed before "django.contrib.admin" in settings

**Admin Class Patterns:**
- Always import from `unfold.admin` instead of `django.contrib.admin`
- Use `ModelAdmin` from `unfold.admin` for model admin classes
- Use `TabularInline` from `unfold.admin` for inline classes (not Django's default)
- Use `StackedInline` from `unfold.admin` for stacked inline classes

**Example Admin Structure:**
```python
from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline

from .models import MyModel, RelatedModel


class RelatedModelInline(TabularInline):  # Use Unfold's TabularInline
    model = RelatedModel
    extra = 1
    fields = ["name", "status"]


@admin.register(MyModel)
class MyModelAdmin(ModelAdmin):  # Use Unfold's ModelAdmin
    list_display = ["name", "status", "created"]
    list_filter = ["status"]
    search_fields = ["name"]
    inlines = [RelatedModelInline]
```
