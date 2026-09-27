import pytest
from django.db import IntegrityError, transaction
from django.test import Client
from model_bakery import baker

from core.models import User

pytestmark = pytest.mark.django_db
PASSWORD = "test-password-8492"


@pytest.fixture
def user():
    user = baker.make(User, email="member@example.test", first_name="Ada", last_name="Lovelace")
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


def test_superuser_is_created_by_email_without_username():
    admin = User.objects.create_superuser(email="admin@example.test", password=PASSWORD)
    assert admin.is_staff and admin.is_superuser
    assert User.USERNAME_FIELD == "email"
    assert "username" not in {field.name for field in User._meta.get_fields()}


def test_admin_creates_users_by_email(client):
    client.force_login(User.objects.create_superuser(email="admin@example.test", password=PASSWORD))
    assert client.get("/admin/core/user/").status_code == 200
    response = client.post(
        "/admin/core/user/add/",
        {"email": "staff-made@example.test", "password1": PASSWORD, "password2": PASSWORD},
    )
    assert response.status_code == 302
    created = User.objects.get(email="staff-made@example.test")
    assert client.get(f"/admin/core/user/{created.pk}/change/").status_code == 200


def login_as(browser, email):
    return browser.post(
        "/api/auth/browser/v1/auth/login",
        {"email": email, "password": PASSWORD},
        content_type="application/json",
        **csrf(browser),
    )


@pytest.fixture
def admin_client(client):
    client.force_login(User.objects.create_superuser(email="admin@example.test", password=PASSWORD))
    return client


@pytest.mark.parametrize("submitted", ["Mixed.Case@Example.Test", "mixed.case@example.test"])
def test_manager_created_mixed_case_email_can_log_in(browser, submitted):
    user = User.objects.create_user(email="Mixed.Case@Example.Test", password=PASSWORD)
    assert user.email == "mixed.case@example.test"
    assert login_as(browser, submitted).status_code == 200
    assert browser.get("/api/me").json()["id"] == user.pk


@pytest.mark.parametrize("submitted", ["Staff.Made@Example.Test", "staff.made@example.test"])
def test_admin_created_mixed_case_email_can_log_in(admin_client, browser, submitted):
    response = admin_client.post(
        "/admin/core/user/add/",
        {"email": "Staff.Made@Example.Test", "password1": PASSWORD, "password2": PASSWORD},
    )
    assert response.status_code == 302
    user = User.objects.get(email="staff.made@example.test")
    assert login_as(browser, submitted).status_code == 200
    assert browser.get("/api/me").json()["id"] == user.pk


def test_admin_email_edit_is_normalized(admin_client, browser, user):
    response = admin_client.post(
        f"/admin/core/user/{user.pk}/change/",
        {
            "email": "Renamed@Example.Test",
            "first_name": user.first_name,
            "last_name": user.last_name,
            "is_active": "on",
            "last_login_0": "",
            "last_login_1": "",
            "date_joined_0": user.date_joined.strftime("%Y-%m-%d"),
            "date_joined_1": user.date_joined.strftime("%H:%M:%S"),
        },
    )
    assert response.status_code == 302, response.context["adminform"].form.errors
    user.refresh_from_db()
    assert user.email == "renamed@example.test"
    assert login_as(browser, "Renamed@Example.Test").status_code == 200


def test_admin_rejects_email_differing_only_by_case(admin_client, user):
    response = admin_client.post(
        "/admin/core/user/add/",
        {"email": "MEMBER@Example.Test", "password1": PASSWORD, "password2": PASSWORD},
    )
    assert response.status_code == 200
    assert "email" in response.context["adminform"].form.errors
    assert User.objects.filter(email__iexact="member@example.test").count() == 1
