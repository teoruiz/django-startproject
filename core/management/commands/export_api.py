import json
from pathlib import Path

from allauth.headless.spec.views import OpenAPIJSONView
from django.core.management.base import BaseCommand
from django.http import HttpResponse
from django.test import RequestFactory

from core.api import api


class Command(BaseCommand):
    help = "Export the Ninja and installed allauth schemas without a running server or database."

    def handle(self, *args, **options):
        destination = Path("frontend/.schema")
        destination.mkdir(exist_ok=True)
        response = OpenAPIJSONView.as_view()(RequestFactory().get("/api/auth/openapi.json"))
        assert isinstance(response, HttpResponse)
        schemas = {"api": api.get_openapi_schema(), "auth": json.loads(response.content)}
        for name, schema in schemas.items():
            (destination / f"{name}.json").write_text(json.dumps(schema, indent=2, sort_keys=True) + "\n")
