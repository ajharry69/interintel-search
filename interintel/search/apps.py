from django import apps


class AppConfig(apps.AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'interintel.search'
