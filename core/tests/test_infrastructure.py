from unittest.mock import patch

import pytest
from django.db.utils import OperationalError
from django.tasks import TaskResultStatus

from core.tasks import welcome_message


def test_native_task_enqueue_executes_with_immediate_backend():
    result = welcome_message.enqueue("Ada")
    assert result.status == TaskResultStatus.SUCCESSFUL
    assert result.return_value == "Welcome, Ada!"


@pytest.mark.django_db
def test_health_checks_database(client):
    assert client.get("/health/").json() == {"status": "ok"}
    with patch("core.views.connection.cursor", side_effect=OperationalError("unavailable")):
        response = client.get("/health/")
    assert response.status_code == 503
    assert response.json() == {"status": "unavailable"}


def test_contract_documents_cookie_auth(client):
    schema = client.get("/api/openapi.json").json()
    assert schema["paths"]["/api/me"]["get"]["security"]
    assert schema["paths"]["/api/me"]["get"]["operationId"] == "getCurrentUser"
    assert "/api/auth/browser/v1/auth/login" in client.get("/api/auth/openapi.json").json()["paths"]
