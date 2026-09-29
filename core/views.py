from django.conf import settings
from django.db import connection
from django.db.utils import DatabaseError
from django.http import HttpRequest, HttpResponse, HttpResponseNotFound, JsonResponse
from django.views.decorators.cache import cache_control
from django.views.decorators.http import require_GET, require_safe
from django.views.decorators.vary import vary_on_headers


@require_GET
def health(request: HttpRequest) -> JsonResponse:
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except DatabaseError:
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})


@cache_control(no_cache=True)
@vary_on_headers("Accept")
@require_safe
def frontend(request: HttpRequest) -> HttpResponse:
    """Serve the built React entry page for browser navigations; React Router renders the route."""
    # Scripts, images, fetch() and API clients do not ask for HTML and get a 404 instead of the SPA.
    if not any(media.main_type == "text" and media.sub_type == "html" for media in request.accepted_types):
        return HttpResponseNotFound("Only HTML navigations load the frontend.")
    try:
        html = (settings.FRONTEND_DIR / "index.html").read_bytes()
    except FileNotFoundError:
        return HttpResponseNotFound("The frontend has not been built. In development, open the Vite server.")
    # Every response, including rejections, varies on Accept and must revalidate.
    return HttpResponse(html, content_type="text/html; charset=utf-8")
