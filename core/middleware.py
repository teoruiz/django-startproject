from collections.abc import Callable

from django.http import HttpRequest, HttpResponse
from django.utils.cache import add_never_cache_headers
from whitenoise.middleware import WhiteNoiseMiddleware


class StaticFilesMiddleware(WhiteNoiseMiddleware):
    """Serve collectstatic output and the Vite build (WHITENOISE_ROOT) with release-safe caching."""

    def immutable_file_test(self, path: str, url: str) -> bool:
        # Vite content-hashes every file it emits under assets/; Django's manifest covers /static/.
        return url.startswith("/assets/") or super().immutable_file_test(path, url)

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
