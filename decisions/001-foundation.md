# Foundation

Accepted: Django owns the application and PostgreSQL is its authoritative database.
React owns product presentation. Ninja OpenAPI generates business API TypeScript types consumed by openapi-fetch.
Allauth owns authentication; its installed OpenAPI schema generates a separate authentication client type file.
Browser clients use session cookies and CSRF through same-origin `/api` paths. No tokens are stored in localStorage.
A small custom Django user model permits future identity changes without replacing AUTH_USER_MODEL after deployment.
Email is the only identifier: it is unique, used for sign-in, admin and `createsuperuser`. There is no username.

Native `django.tasks` is the only application-facing task API. ImmediateBackend runs synchronously for development
and tests and provides no durable queue. Before relying on background execution in production, choose a backend
(such as django-tasks-db), delivery/retry policy, worker lifecycle and monitoring. Use transaction.on_commit when
queueing tasks that depend on committed database state.

Development runs Django and Vite on the host; Compose contains only PostgreSQL (see 002). The backend release image
serves Django/admin static files only.
Frontend hosting is intentionally undecided; a production design must supply SPA fallback and a same-origin API
route or explicitly configure cross-origin cookies, CSRF and CORS. Do not infer deployment readiness from a build.

Supabase is absent. Realtime or Storage may later be infrastructure services; no Supabase Auth, browser/database CRUD,
Edge Functions or business authorization in RLS. Go is absent; it is reserved for genuinely independent services.
