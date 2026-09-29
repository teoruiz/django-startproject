import json

import pytest

INDEX = b'<!doctype html><div id="root"></div><script type="module" src="/assets/index-Ab1_cD2e.js"></script>'
HTML = {"HTTP_ACCEPT": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}


@pytest.fixture
def build(settings):
    """A minimal Vite build; the fixture must run before the first request so WhiteNoise indexes it."""
    (settings.FRONTEND_DIR / "assets").mkdir()
    (settings.FRONTEND_DIR / "index.html").write_bytes(INDEX)
    (settings.FRONTEND_DIR / "assets" / "index-Ab1_cD2e.js").write_text("console.log('app')")
    (settings.FRONTEND_DIR / "assets" / "index-Cd3_eF4g.css").write_text("body { margin: 0 }")
    (settings.FRONTEND_DIR / "assets" / "icon-Ef5_gH6i.svg").write_text("<svg/>")
    (settings.FRONTEND_DIR / ".vite").mkdir()
    (settings.FRONTEND_DIR / ".vite" / "manifest.json").write_text(
        json.dumps(
            {
                "index.html": {
                    "file": "assets/index-Ab1_cD2e.js",
                    "css": ["assets/index-Cd3_eF4g.css"],
                    "assets": ["assets/icon-Ef5_gH6i.svg"],
                }
            }
        )
    )
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
        assert response["Cache-Control"] == "no-cache"
        assert "Accept" in response["Vary"]


@pytest.mark.parametrize("method", ["get", "head"])
@pytest.mark.parametrize("accept", ["*/*", "application/json", "image/avif,image/webp,*/*;q=0.8", "text/html;q=0"])
def test_non_navigation_requests_do_not_get_the_spa(client, build, accept, method):
    response = getattr(client, method)("/account", HTTP_ACCEPT=accept)
    assert response.status_code == 404
    assert response.content != INDEX
    assert response["Cache-Control"] == "no-cache"
    assert "Accept" in response["Vary"]
    # The same URL still serves HTML after the rejected request.
    assert client.get("/account", **HTML).content == INDEX


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


@pytest.mark.parametrize("filename", ["index-Ab1_cD2e.js", "index-Cd3_eF4g.css", "icon-Ef5_gH6i.svg"])
def test_manifest_assets_are_immutable(client, build, filename):
    asset = client.get(f"/assets/{filename}")
    assert asset.status_code == 200
    assert asset["Cache-Control"] == "max-age=315360000, public, immutable"


@pytest.mark.parametrize("path", ["robots.txt", "assets/logo.svg", "assets/logo-Ab1_cD2e.svg"])
def test_public_files_are_not_immutable_even_with_hash_like_names(client, build, path):
    (build / path).write_text("public file")
    asset = client.get(f"/{path}")
    assert asset.status_code == 200
    assert "immutable" not in asset["Cache-Control"]
    # Direct requests for the entry file also revalidate.
    assert client.get("/index.html")["Cache-Control"] == "no-cache"


@pytest.mark.django_db
def test_api_responses_are_not_cacheable(client):
    for path in ("/api/me", "/api/csrf", "/api/auth/browser/v1/auth/session"):
        cache_control = client.get(path)["Cache-Control"]
        assert "no-store" in cache_control and "private" in cache_control, path


def test_assets_without_a_manifest_are_not_immutable(client, build):
    (build / ".vite" / "manifest.json").unlink()
    asset = client.get("/assets/index-Ab1_cD2e.js")
    assert asset.status_code == 200
    assert "immutable" not in asset["Cache-Control"]


def test_missing_build_is_a_404_not_an_error(client):
    response = client.get("/", **HTML)
    assert response.status_code == 404
    assert response["Cache-Control"] == "no-cache"
    assert "Accept" in response["Vary"]
