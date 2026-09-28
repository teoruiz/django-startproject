import pytest

INDEX = b'<!doctype html><div id="root"></div><script type="module" src="/assets/index-Ab1_cD2e.js"></script>'
HTML = {"HTTP_ACCEPT": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}


@pytest.fixture
def build(settings):
    """A minimal Vite build; the fixture must run before the first request so WhiteNoise indexes it."""
    (settings.FRONTEND_DIR / "assets").mkdir()
    (settings.FRONTEND_DIR / "index.html").write_bytes(INDEX)
    (settings.FRONTEND_DIR / "assets" / "index-Ab1_cD2e.js").write_text("console.log('app')")
    (settings.FRONTEND_DIR / "robots.txt").write_text("User-agent: *")
    return settings.FRONTEND_DIR


@pytest.mark.parametrize("path", ["/", "/account", "/account/", "/projects/42/edit", "/apiary", "/administrator"])
def test_navigation_serves_entry_page_that_revalidates(client, build, path):
    response = client.get(path, **HTML)
    assert response.status_code == 200
    assert response.content == INDEX
    assert response["Content-Type"] == "text/html; charset=utf-8"
    assert response["Cache-Control"] == "no-cache"
    assert "Accept" in response["Vary"]
    assert not response.cookies


def test_head_is_allowed_and_other_methods_are_not(client, build):
    assert client.head("/account", **HTML).status_code == 200
    for method in (client.post, client.put, client.patch, client.delete, client.options):
        response = method("/account", **HTML)
        assert response.status_code == 405
        assert response.content != INDEX


@pytest.mark.parametrize("accept", ["*/*", "application/json", "image/avif,image/webp,*/*;q=0.8", "text/html;q=0"])
def test_non_navigation_requests_do_not_get_the_spa(client, build, accept):
    response = client.get("/account", HTTP_ACCEPT=accept)
    assert response.status_code == 404
    assert response.content != INDEX


@pytest.mark.parametrize(
    "path",
    [
        "/api/missing",
        "/api/auth/missing",
        "/assets/missing-Zz9_yY8x.js",
        "/static/missing.css",
        "/media/upload.png",
        "/admin/missing/",
    ],
)
def test_reserved_paths_never_fall_back_to_the_spa(admin_client, build, path):
    response = admin_client.get(path, **HTML)
    assert response.status_code == 404
    assert response.content != INDEX


@pytest.mark.parametrize(("path", "target"), [("/admin", "/admin/"), ("/health", "/health/"), ("/api", "/api/")])
def test_reserved_prefixes_without_slash_redirect_instead_of_loading_the_spa(client, build, path, target):
    response = client.get(path, **HTML)
    assert response.status_code == 301
    assert response["Location"] == target


@pytest.mark.django_db
def test_backend_routes_take_precedence(client, build):
    assert client.get("/health/", **HTML).json() == {"status": "ok"}
    assert client.get("/admin/", **HTML)["Location"].startswith("/admin/login/")
    assert client.get("/api/me", **HTML).status_code == 401
    assert client.get("/api/auth/browser/v1/config", **HTML).status_code == 200


def test_hashed_assets_are_immutable_and_other_build_files_are_not(client, build):
    asset = client.get("/assets/index-Ab1_cD2e.js")
    assert asset.status_code == 200
    assert asset["Cache-Control"] == "max-age=315360000, public, immutable"
    robots = client.get("/robots.txt")
    assert robots.status_code == 200
    assert "immutable" not in robots["Cache-Control"]
    # Direct requests for the entry file also revalidate.
    assert client.get("/index.html")["Cache-Control"] == "no-cache"


@pytest.mark.django_db
def test_api_responses_are_not_cacheable(client):
    for path in ("/api/me", "/api/csrf", "/api/auth/browser/v1/auth/session"):
        cache_control = client.get(path)["Cache-Control"]
        assert "no-store" in cache_control and "private" in cache_control, path


def test_missing_build_is_a_404_not_an_error(client):
    assert client.get("/", **HTML).status_code == 404
