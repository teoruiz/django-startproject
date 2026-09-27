from typing import Any, ClassVar

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.db.models.functions import Lower
from django_extensions.db.models import TimeStampedModel


class UserManager(BaseUserManager["User"]):
    """Create users by email; there is no username."""

    use_in_migrations = True

    @classmethod
    def normalize_email(cls, email: str | None) -> str:
        # Django lowercases only the domain; allauth matches the whole address in lowercase.
        return super().normalize_email(email).strip().lower()

    def _create_user(self, email: str, password: str | None, **extra_fields: Any) -> "User":
        if not email:
            raise ValueError("Users must have an email address.")
        user = self.model(email=self.normalize_email(email), **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email: str, password: str | None = None, **extra_fields: Any) -> "User":
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email: str, password: str | None = None, **extra_fields: Any) -> "User":
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        if not extra_fields["is_staff"] or not extra_fields["is_superuser"]:
            raise ValueError("Superusers must have is_staff=True and is_superuser=True.")
        return self._create_user(email, password, **extra_fields)


class User(AbstractUser, TimeStampedModel):
    """Keep identity extensible from the first migration; allauth handles sign-in."""

    username = None  # pyright: ignore[reportAssignmentType]
    email = models.EmailField(unique=True, help_text="Unique email used to sign in.")

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: ClassVar[list[str]] = []

    objects: ClassVar[UserManager] = UserManager()  # pyright: ignore[reportIncompatibleVariableOverride]

    class Meta(AbstractUser.Meta, TimeStampedModel.Meta):
        abstract = False
        constraints = [models.UniqueConstraint(Lower("email"), name="core_user_email_ci_unique")]
        ordering = ["-created"]
        verbose_name = "user"
        verbose_name_plural = "users"

    def save(self, *args: Any, **kwargs: Any) -> None:
        # clean() normalizes for forms; this also covers the manager, shell and fixtures.
        self.email = UserManager.normalize_email(self.email)
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return self.email
