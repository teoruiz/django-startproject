# UX workspace

Paper is the intended visual design workspace. Record the Paper document/frame links here as a product develops.
Before implementing a flow, describe its entry points, states, errors and acceptance criteria.
Use shadcn/ui in `frontend/src/components/ui` and shared project/domain components.

## Starter sign-in flow

- `/` explains the empty workspace and links to `/account`.
- `/account` checks the session, showing loading and a recoverable service error when appropriate.
- An anonymous user sees an email/password form. Invalid credentials show a generic accessible error.
- Sign-in uses allauth Headless with CSRF and an HttpOnly session cookie.
- A signed-in user sees their own display name and email from the typed Ninja `/api/me` endpoint.
- Refresh preserves the session. Sign-out clears the session and cached private data.
- Unknown routes show a not-found page with a home link.
- Public signup, password recovery and email verification screens are deferred; provision accounts through Django.

Verify routing, invalid and valid login, refresh, sign-out, and runtime errors with agent-browser.
Playwright is not a baseline dependency; add persistent browser tests only for regression-critical flows.
