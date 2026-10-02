from django.tasks import task


@task
def welcome_message(name: str) -> str:
    """Small native Tasks example. No durable/background execution is assumed."""
    return f"Welcome, {name}!"
