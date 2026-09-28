from django.conf import settings
from django.db import connection
from django.db.utils import DatabaseError
from django.http import Http404, HttpRequest, HttpResponse, JsonResponse
from django.utils.cache import patch_vary_headers
from django.views.decorators.http import require_GET, require_safe


@require_GET
def health(request: HttpRequest) -> JsonResponse:
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except DatabaseError:
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})


@require_safe
def frontend(request: HttpRequest) -> HttpResponse:
    """Serve the built React entry page for browser navigations; React Router renders the route."""
    # Scripts, images, fetch() and API clients do not ask for HTML and get a 404 instead of the SPA.
    if not any(media.main_type == "text" and media.sub_type == "html" for media in request.accepted_types):
        raise Http404("Only HTML navigations load the frontend.")
    try:
        html = (settings.FRONTEND_DIR / "index.html").read_bytes()
    except FileNotFoundError:
        raise Http404("The frontend has not been built. In development, open the Vite server.") from None
    response = HttpResponse(html, content_type="text/html; charset=utf-8")
    # The entry page names the current release's hashed assets, so clients must revalidate it.
    response["Cache-Control"] = "no-cache"
    patch_vary_headers(response, ["Accept"])
    return response
