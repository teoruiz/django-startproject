# Backend conventions

Read the relevant [domain notes](../domains/README.md) and [architecture](architecture.md) before changing behavior.
These conventions apply to application code; document domain-specific exceptions where they arise.

## Models and fields

- Use `TimeStampedModel` from `django_extensions.db.models` for application models so they have `created` and `modified`.
  Preserve the existing `core.User` base classes and manager when extending identity.
- Define status/type choices as nested `models.TextChoices` classes near the top of the model. Use stable stored values
  and readable labels; choose defaults that represent a valid initial domain state.
- Give fields descriptive names and `help_text` explaining their purpose or business meaning. Use `CharField` for bounded
  strings and `TextField` for longer text. Keep API validation and database field limits consistent.
- Choose `blank`, `null` and defaults deliberately: form optionality and database nullability are different decisions.
  Use callable defaults such as `list` or `dict` for mutable values.
- Set descriptive `related_name` values and explicit `on_delete` behavior. Choose `PROTECT`, `CASCADE` or `SET_NULL`
  from the relationship's lifecycle; use `null=True` with `SET_NULL` and `blank=True` when forms may omit the relation.
- Use related models for data with its own identity or relationships. PostgreSQL-specific fields such as `ArrayField`
  require a concrete domain need and an explicit decision about the disposable SQLite validation path; they are not
  the default representation for every list. PostgreSQL remains the authoritative database target.
- Define meaningful `verbose_name` / `verbose_name_plural` and default ordering when the domain needs it.
  Newest-first `ordering = ["-created"]` is a useful default for activity records, not a rule for every model.
- Implement a meaningful, inexpensive `__str__()`. Use properties for inexpensive derived values; avoid surprising writes
  or repeated database queries from properties, serializers and admin list displays.

## Invariants, permissions and workflows

- Enforce business rules in Django so API calls, admin actions and tasks follow the same rules. Do not rely on UI validation
  or frontend route guards. Use database constraints for invariants that must hold across concurrent writes.
- Keep API handlers focused on validation, authorization and delegation. Introduce shared workflow functions when multiple
  callers need them; do not create generic service/repository layers around straightforward ORM operations.
- Scope querysets to the actor's permitted objects and check action-specific permissions before writes.
  Use `settings.AUTH_USER_MODEL` for relationships to users; do not create a second identity system.
- Group dependent writes in transactions. Do not rely on `save()` overrides or form validation to cover bulk updates,
  raw fixture loading or every other write path. Test the paths a workflow actually uses.
- Use `@task` from `django.tasks` and `.enqueue(...)`. Pass serializable arguments, typically object IDs.
  Use `transaction.on_commit` when a task depends on committed writes. ImmediateBackend executes synchronously;
  do not assume background delivery, retries or durable results until a production backend is deliberately configured.

## Migrations and tests

- Generate migrations with `just manage makemigrations`, inspect the operations and apply with `just manage migrate`.
  Commit migrations with their model changes. Do not rewrite migrations already applied to shared environments.
- Use historical models through `apps.get_model` in data migrations. Plan existing-data handling before adding non-null
  fields or constraints; do not silently discard data to make a migration pass.
- Run focused pytest/pytest-django tests and `just check`. Cover meaningful invariants, permission denial, workflow transitions
  and regressions. Use model-bakery for incidental test data; exercise real creation/login paths when testing identity.
- Check migration drift with `just manage makemigrations --check --dry-run`. Validate PostgreSQL-specific behavior against
  PostgreSQL; passing the template's SQLite loop is not proof of PostgreSQL behavior.
- Use the configured Ruff and basedpyright checks. Keep type suppressions narrow and explain integration limitations
  where they occur instead of weakening checks globally.

## Django admin with Unfold

- Import `ModelAdmin`, `TabularInline` and `StackedInline` from `unfold.admin`. Continue using `django.contrib.admin`
  for registration. Keep `unfold` before `django.contrib.admin` in installed apps.
- Configure useful `list_display`, `list_filter`, `search_fields`, fieldsets and inlines for the actual workflow.
  Treat admin actions as domain entry points with the same invariants and permissions as the API.
- Follow `core/admin.py` for the custom email-only user forms and Django UserAdmin/Unfold integration.
  When changing account provisioning, test the saved password, normalized email and subsequent allauth login.

For dependency commands, lint settings and runtime versions, use [README.md](../README.md), `justfile` and the committed
configuration/lockfiles rather than duplicating those values here.
