from django.contrib.auth.models import AbstractUser
from django.db import models
from django.db.models.functions import Lower
from django_extensions.db.models import TimeStampedModel


class User(AbstractUser, TimeStampedModel):
    """Keep identity extensible from the first migration; allauth handles sign-in."""

    email = models.EmailField(unique=True, help_text="Unique email used to sign in.")

    class Meta(AbstractUser.Meta, TimeStampedModel.Meta):
        abstract = False
        constraints = [models.UniqueConstraint(Lower("email"), name="core_user_email_ci_unique")]
        ordering = ["-created"]
        verbose_name = "user"
        verbose_name_plural = "users"

    def __str__(self) -> str:
        return self.email
