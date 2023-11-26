from django.urls import path

from interintel.search.views import SearchView

app_name = "search"

urlpatterns = [
    path('', SearchView.as_view(), name="index"),
]
