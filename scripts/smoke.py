"""HTTP smoke checks against a running application on one browser origin.

Usage: smoke.py BASE_URL EMAIL PASSWORD [--release]

Always checks allauth Headless sessions, CSRF, Ninja and the native Tasks example. --release also checks a
production image (DEBUG=false): SPA routing and fallback limits, cache headers, compression and secure cookies.
"""

import re
import sys

import httpx

NAVIGATION = {"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}
IMMUTABLE = "max-age=315360000, public, immutable"
SPA_MARKER = '<div id="root">'


def check_release(client: httpx.Client) -> None:
    for path in ("/", "/account", "/no/such/page"):
        page = client.get(path, headers=NAVIGATION)
        assert page.status_code == 200, (path, page.status_code)
        assert page.headers["cache-control"] == "no-cache", path
        assert SPA_MARKER in page.text, path
    assert page.headers["server"].startswith("gunicorn")
    assert client.head("/account", headers=NAVIGATION).status_code == 200

    assets = re.findall(r'(?:src|href)="(/assets/[^"]+)"', page.text)
    assert {asset.rsplit(".", 1)[-1] for asset in assets} >= {"js", "css"}, page.text
    login_page = client.get("/admin/login/", headers=NAVIGATION)
    assert login_page.status_code == 200 and "csrfmiddlewaretoken" in login_page.text
    admin_css = re.findall(r'href="(/static/[^"]+\.css)"', login_page.text)
    assert admin_css, login_page.text
    for url in [*assets, *admin_css]:
        response = client.get(url, headers={"Accept-Encoding": "gzip"})
        assert response.status_code == 200, url
        assert response.headers["cache-control"] == IMMUTABLE, url
        assert response.headers.get("content-encoding") == "gzip", url

    for path in ("/assets/missing-00000000.js", "/static/missing.css", "/api/missing", "/media/missing.png"):
        response = client.get(path, headers=NAVIGATION)
        assert response.status_code == 404, (path, response.status_code)
        assert SPA_MARKER not in response.text, path
        assert "URLconf" not in response.text, "DEBUG must be off"
    assert client.get("/account", headers={"Accept": "*/*"}).status_code == 404
    assert client.get("/admin", headers=NAVIGATION).headers["location"] == "/admin/"
    assert client.get("/admin/", headers=NAVIGATION).headers["location"].startswith("/admin/login/")
    assert client.get("/health/").json() == {"status": "ok"}
    assert "no-store" in client.get("/api/me").headers["cache-control"]
    print("Release routing, fallback limits, caching and compression checks passed.")


def main() -> None:
    base_url, email, password = sys.argv[1:4]
    release = sys.argv[4:] == ["--release"]
    with httpx.Client(base_url=base_url) as client:

        def send_secure_cookies_to_localhost(_: httpx.Response) -> None:
            # Browsers send Secure cookies to http://localhost; httpx does not. Set-Cookie flags are asserted below.
            for cookie in client.cookies.jar:
                cookie.secure = False

        client.event_hooks["response"] = [send_secure_cookies_to_localhost]
        assert client.get("/", headers=NAVIGATION).status_code == 200
        if release:
            check_release(client)
        assert client.get("/api/me").status_code == 401
        assert client.get("/api/auth/browser/v1/config").status_code == 200
        login_url = "/api/auth/browser/v1/auth/login"
        credentials = {"email": email, "password": password}
        assert client.post(login_url, json=credentials).status_code == 403  # no CSRF token
        csrf = client.get("/api/csrf")
        response = client.post(login_url, json=credentials, headers={"X-CSRFToken": csrf.json()["csrf_token"]})
        assert response.status_code == 200, response.text
        if release:
            assert "; secure" in csrf.headers["set-cookie"].lower()
            session_cookie = next(c for c in response.headers.get_list("set-cookie") if c.startswith("sessionid="))
            assert {"; secure", "; httponly"} <= set(re.findall(r"; \w+", session_cookie.lower())), session_cookie
        assert client.get("/api/me").json()["email"] == email.lower()
        assert client.post("/api/tasks/welcome").status_code == 403  # login rotated the CSRF secret
        token = client.get("/api/csrf").json()["csrf_token"]
        task = client.post("/api/tasks/welcome", headers={"X-CSRFToken": token})
        assert task.status_code == 200 and task.json()["task_id"], task.text
        if release:
            assert client.post("/account", headers={**NAVIGATION, "X-CSRFToken": token}).status_code == 405
        logout = client.delete("/api/auth/browser/v1/auth/session", headers={"X-CSRFToken": token})
        assert logout.status_code == 401
        assert client.get("/api/me").status_code == 401
    print("Session, CSRF, Ninja and task checks passed.")


if __name__ == "__main__":
    main()
