import json
from collections.abc import Callable

from django.conf import settings
from django.http import HttpRequest, HttpResponse
from django.utils.cache import add_never_cache_headers
from whitenoise.middleware import WhiteNoiseMiddleware


class StaticFilesMiddleware(WhiteNoiseMiddleware):
    """Serve collectstatic output and the Vite build (WHITENOISE_ROOT) with release-safe caching."""

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        try:
            manifest = json.loads((settings.FRONTEND_DIR / ".vite" / "manifest.json").read_text())
        except FileNotFoundError:
            # Backend development and tests do not require a frontend build.
            manifest = {}
        self.frontend_asset_urls = {
            f"/{filename}"
            for chunk in manifest.values()
            for filename in (chunk["file"], *chunk.get("css", []), *chunk.get("assets", []))
        }
        super().__init__(get_response)

    def immutable_file_test(self, path: str, url: str) -> bool:
        # Only Vite's manifest proves a build asset is versioned; public/ files are copied unchanged.
        return url in self.frontend_asset_urls or super().immutable_file_test(path, url)

    def add_cache_headers(self, headers, path: str, url: str) -> None:
        super().add_cache_headers(headers, path, url)
        if url.endswith(".html"):
            # HTML references the current release's hashed assets, so it must always revalidate.
            headers["Cache-Control"] = "no-cache"


def api_never_cache(get_response: Callable[[HttpRequest], HttpResponse]) -> Callable[[HttpRequest], HttpResponse]:
    """Keep session-authenticated API responses out of browser and shared caches unless a view opts in."""

    def middleware(request: HttpRequest) -> HttpResponse:
        response = get_response(request)
        if request.path_info.startswith("/api/") and not response.has_header("Cache-Control"):
            add_never_cache_headers(response)
        return response

    return middleware
