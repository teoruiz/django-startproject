from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .models import User


# Unfold documents this mixin order; its get_form signature is narrower than Django's stubs.
@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):  # pyright: ignore[reportIncompatibleMethodOverride]
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm
    list_display = ["email", "username", "is_staff", "is_active"]
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("username", "email", "password1", "password2")}),)
