from django.http import HttpRequest
from django.middleware.csrf import get_token
from ninja import NinjaAPI, Schema
from ninja.security import django_auth

from .models import User
from .tasks import welcome_message

api = NinjaAPI(title="Application API", version="1.0.0", auth=django_auth)


class UserSchema(Schema):
    id: int
    email: str
    display_name: str


class CsrfSchema(Schema):
    csrf_token: str


class TaskSchema(Schema):
    task_id: str


@api.get("/csrf", auth=None, response=CsrfSchema, operation_id="getCsrfToken")
def csrf(request: HttpRequest) -> CsrfSchema:
    return CsrfSchema(csrf_token=get_token(request))


@api.get("/me", response=UserSchema, operation_id="getCurrentUser")
def me(request: HttpRequest) -> UserSchema:
    # Authentication selects the current user. Never accept a client-provided user ID here.
    assert isinstance(request.user, User)
    return UserSchema(
        id=request.user.pk,
        email=request.user.email,
        display_name=request.user.get_full_name() or request.user.email,
    )


@api.post("/tasks/welcome", response=TaskSchema, operation_id="enqueueWelcome")
def enqueue_welcome(request: HttpRequest) -> TaskSchema:
    assert isinstance(request.user, User)
    result = welcome_message.enqueue(request.user.get_full_name() or request.user.email)
    return TaskSchema(task_id=result.id)
