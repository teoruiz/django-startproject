<h1 align="center">Welcome to django-startproject 👋</h1>
<p>
  <a href="https://github.com/teoruiz/django-startproject/actions" target="_blank">
    <img alt="CI" src="https://github.com/teoruiz/django-startproject/workflows/CI/badge.svg" />
  </a>
</p>

> Django startproject template with batteries
>
> Forked from [jefftriplett/django-startproject](https://github.com/jefftriplett/django-startproject) with modern frontend tooling and API support

## :triangular_flag_on_post: Core Features

- Django 5.2
- Python 3.13
- Docker Compose (I prefer Orbstack)
- Justfile recipes
- Postgres auto updates
- uv support
- pre-commit support via prek

## :triangular_flag_on_post: Django Features

- django-click
- django-prodserver
- django-ninja (REST API framework)
- django-htmx (dynamic interactions)
- django-storages
- django-extensions
- django-tailwind-cli (with django-extensions support)
- environs[django]
- psycopg[binary]
- whitenoise
- httpx
- uvicorn

## :art: Frontend

- Tailwind CSS v4 (CSS-first configuration)
- DaisyUI (component library)
- HTMX (dynamic interactions)
- Dark mode support

## :shirt: Linting/auto-formatting

- pre-commit (using prek)
  - Standard hooks (check-added-large-files, check-json, check-toml, check-yaml, etc.)
  - ruff (linting and formatting)
  - djlint (Django template linting)
  - pyupgrade (Python 3.13+)
  - django-upgrade (Django 5.0+)
  - djhtml (Django template formatting)
  - djade (Django 5.2 compatibility)
  - blacken-docs (format code in documentation)

## :green_heart: Testing

- django-test-plus
- django-browser-reload (dev)
- model-bakery
- pytest
- pytest-django

## 📚 Additional Features

- Multi-stage Docker build (dev/release)
- CLAUDE.md included for AI-assisted development
- llms.txt for LLM context
- Base templates with Tailwind CSS v4
- Django Ninja API (`/api/hello` example endpoint)

### 🏠 [Homepage](https://github.com/teoruiz/django-startproject)
### 🔗 [Original Project](https://github.com/jefftriplett/django-startproject)

## :wrench: Install

```shell
$ uv run --with=django django-admin startproject \
    --extension=ini,py,toml,yaml,yml \
    --template=https://github.com/teoruiz/django-startproject/archive/main.zip \
    example_project

$ cd example_project

$ just bootstrap
```

## :rocket: Usage

```shell
# Bootstrap our project
$ just bootstrap

# Build our Docker Image
$ just build

# Run Migrations
$ just manage migrate

# Create a Superuser in Django
$ just manage createsuperuser

# Run Django on http://localhost:8000/
$ just up

# Run Django in background mode
$ just start

# Stop all running containers
$ just down

# Open a bash shell/console
$ just console

# Run Tests
$ just test

# Lint the project / run pre-commit by hand
$ just lint

# Lock dependencies with uv
$ just lock
```

## `just` Commands

```shell
$ just --list
```
<!-- [[[cog
import subprocess
import cog

list = subprocess.run(['just', '--list'], stdout=subprocess.PIPE)
cog.out(
    f"```\n{list.stdout.decode('utf-8')}```"
)
]]] -->
```
Available recipes:
    bootstrap *ARGS           # Initialize project with dependencies and environment
    build *ARGS               # Build Docker containers with optional args
    console                   # Open interactive bash console in utility container
    down *ARGS                # Stop and remove containers, networks
    lint *ARGS                # Run pre-commit hooks on all files
    lint-autoupdate *ARGS     # Update pre-commit hooks to latest versions
    lock *ARGS                # Lock dependencies with uv
    logs *ARGS                # Show logs from containers
    manage *ARGS              # Run Django management commands
    pg_dump file='db.dump'    # Dump database to file
    pg_restore file='db.dump' # Restore database dump from file
    restart *ARGS             # Restart containers
    run *ARGS                 # Run command in utility container
    start *ARGS="--detach"    # Start services in detached mode by default
    stop *ARGS                # Stop services (alias for down)
    tail                      # Show and follow logs
    test *ARGS                # Run pytest with arguments
    up *ARGS                  # Start containers
    upgrade                   # Upgrade dependencies and lock
```
<!-- [[[end]]] -->

## Authors

👤 **Teo Ruiz** (Fork maintainer)

* GitHub: [@teoruiz](https://github.com/teoruiz)

👤 **Jeff Triplett** (Original author)

* Website: https://jefftriplett.com
* Micro Blog: https://micro.webology.dev
* Mastodon: [@webology@mastodon.social](https://mastodon.social/@webology)
* Xwitter: [@webology](https://twitter.com/webology)
* GitHub: [@jefftriplett](https://github.com/jefftriplett)
* Hire me: [revsys](https://www.revsys.com)

## 🌟 Community Projects

* [Django News Newsletter](https://django-news.com)
* [Django News Jobs](https://jobs.django-news.com)
* [Django Packages](https://djangopackages.org)
* [DjangoCon US](https://djangocon.us)
* [Awesome Django](https://awesomedjango.org)

## 🤝 Contributing

Contributions, issues and feature requests are welcome!<br />Feel free to check [issues page](https://github.com/teoruiz/django-startproject/issues).

## Show your support

Give a ⭐️ if this project helped you!
