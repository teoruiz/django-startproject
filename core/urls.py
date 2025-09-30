from django.urls import path
from .views import HomeView

from .api import api

urlpatterns = [
    path("", HomeView.as_view(), name="home"),
    path("api/", api.urls),
]
