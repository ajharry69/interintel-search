from os import environ

SECRET_KEY = environ.get("SECRET_KEY")

CSRF_COOKIE_SECURE = True

SESSION_COOKIE_SECURE = True

SECURE_SSL_REDIRECT = True

DATABASES = {
    'default': {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": environ.setdefault("DB_NAME", "interintel"),
        "USER": environ.setdefault("DB_USER", "postgres"),
        "PASSWORD": environ.setdefault("DB_PASSWORD", ""),
        "HOST": environ.setdefault("DB_HOST", "localhost"),
    }
}
