# Browser verification

Use a disposable **generated** project with PostgreSQL: `TEMPLATE_KEEP=1 just template-test compose`.
In the printed project directory, create an account with `just manage createsuperuser`.
Use an isolated agent-browser session; do not save auth state in the repository.

```sh
agent-browser --session starter open http://localhost:5173
agent-browser --session starter snapshot -i
# Click Account, snapshot again, then fill Email and Password and submit.
agent-browser --session starter snapshot -i
agent-browser --session starter errors
agent-browser --session starter console
agent-browser --session starter screenshot /tmp/starter-account.png
```

Verify these acceptance criteria:

1. Home loads; Account navigation and direct `/account` navigation work.
2. Invalid credentials show an accessible error; no private data appears.
3. A valid login goes through `/api/auth/browser/v1/auth/login`.
4. `/api/me` returns the signed-in user's typed data, and the page renders their name/email.
5. Refresh preserves authentication. Unknown routes show the not-found screen.
6. Sign-out returns to the form; subsequent `/api/me` requests are unauthorized.
7. There are no unexpected console errors, failed asset requests or runtime exceptions.
   HTTP 401 for anonymous `/api/me` and successful allauth logout, and 400 for deliberately invalid
   credentials, are expected protocol responses.
8. Check a narrow viewport for overflow and usable form controls.

Close the browser session and run the printed disposable cleanup command when finished.
Do not add Playwright dependencies just to run this manual verification. Persistent browser tests
are a separate product decision for important regression-critical flows.

## Foundation validation record — 2026-09-27

Validated fresh artifacts generated from the local working template:

- `just template-test`: install, checks, migrations/drift, 13 pytest tests, Ruff/ESLint/Prettier,
  basedpyright (zero errors/warnings), TypeScript, schema drift check and Vite production build passed.
- `just template-test compose`: the same checks passed with PostgreSQL 17, plus clean bootstrap,
  healthy Django/Vite services and backend release-image construction.
- The release image served database health, Unfold admin HTML/static and the allauth OpenAPI schema
  with DEBUG disabled and no pytest/development dependencies installed.
- agent-browser verified invalid/valid login, typed authenticated data rendering, refresh, logout
  and subsequent API denial, routing/not-found, 390px viewport without horizontal overflow,
  native task enqueueing and the Unfold user form. No browser runtime exceptions were recorded.
- Generation probes verified secret/cache exclusions, unchanged JSX/CI expressions, Django variable
  substitution. A deliberate contract change was rejected. Normal generation now uses Django's standard
  command; checkout filtering is internal to template validation.

These are local validation results, not evidence of a hosted deployment. Re-run the recipes after changes.
