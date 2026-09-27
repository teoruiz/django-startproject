import pytest
from django.db import IntegrityError, transaction
from django.test import Client
from model_bakery import baker

from core.models import User

pytestmark = pytest.mark.django_db
PASSWORD = "test-password-8492"


@pytest.fixture
def user():
    user = baker.make(User, email="member@example.test", username="member", first_name="Ada", last_name="Lovelace")
    user.set_password(PASSWORD)
    user.save()
    return user


@pytest.fixture
def browser():
    return Client(enforce_csrf_checks=True)


def csrf(browser):
    response = browser.get("/api/csrf")
    assert response.status_code == 200
    return {"HTTP_X_CSRFTOKEN": response.json()["csrf_token"]}


def login(browser, password=PASSWORD):
    return browser.post(
        "/api/auth/browser/v1/auth/login",
        {"email": "member@example.test", "password": password},
        content_type="application/json",
        **csrf(browser),
    )


def test_anonymous_cannot_read_user_or_enqueue(browser):
    assert browser.get("/api/me").status_code == 401
    assert browser.post("/api/tasks/welcome", **csrf(browser)).status_code == 401


def test_login_requires_csrf(browser, user):
    response = browser.post(
        "/api/auth/browser/v1/auth/login",
        {"email": user.email, "password": PASSWORD},
        content_type="application/json",
    )
    assert response.status_code == 403
    assert browser.get("/api/me").status_code == 401


def test_wrong_password_rejected(browser, user):
    assert login(browser, password="wrong").status_code == 400
    assert browser.get("/api/me").status_code == 401


def test_headless_session_authorizes_ninja_and_logout_revokes_it(browser, user):
    assert login(browser).status_code == 200
    assert browser.cookies["sessionid"]["httponly"]
    response = browser.get("/api/me")
    assert response.status_code == 200
    assert response.json() == {"id": user.pk, "email": user.email, "display_name": "Ada Lovelace"}
    # Mutations still require CSRF after authentication, including Ninja operations.
    assert browser.post("/api/tasks/welcome").status_code == 403
    task = browser.post("/api/tasks/welcome", **csrf(browser))
    assert task.status_code == 200
    assert task.json()["task_id"]
    assert browser.delete("/api/auth/browser/v1/auth/session").status_code == 403
    assert browser.delete("/api/auth/browser/v1/auth/session", **csrf(browser)).status_code == 401
    assert browser.get("/api/me").status_code == 401


def test_identity_cannot_be_selected_by_client(browser, user):
    other = baker.make(User, email="other@example.test")
    assert login(browser).status_code == 200
    assert browser.get(f"/api/me?user_id={other.pk}").json()["id"] == user.pk


def test_disabled_user_cannot_login(browser, user):
    user.is_active = False
    user.save()
    assert login(browser).status_code == 401
    assert browser.get("/api/me").status_code == 401


def test_signup_is_closed(browser):
    response = browser.post(
        "/api/auth/browser/v1/auth/signup",
        {"email": "new@example.test", "password": PASSWORD},
        content_type="application/json",
        **csrf(browser),
    )
    assert response.status_code == 403
    assert not User.objects.filter(email="new@example.test").exists()


def test_untrusted_origin_rejected(browser, user):
    response = browser.post(
        "/api/auth/browser/v1/auth/login",
        {"email": user.email, "password": PASSWORD},
        content_type="application/json",
        HTTP_ORIGIN="https://untrusted.example",
        **csrf(browser),
    )
    assert response.status_code == 403


def test_login_email_is_case_insensitive(browser, user):
    response = browser.post(
        "/api/auth/browser/v1/auth/login",
        {"email": "MEMBER@EXAMPLE.TEST", "password": PASSWORD},
        content_type="application/json",
        **csrf(browser),
    )
    assert response.status_code == 200
    assert browser.get("/api/me").json()["id"] == user.pk


def test_email_uniqueness_is_enforced_case_insensitively(user):
    with pytest.raises(IntegrityError), transaction.atomic():
        baker.make(User, email="MEMBER@example.test")
