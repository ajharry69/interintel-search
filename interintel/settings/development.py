from .base import INSTALLED_APPS, MIDDLEWARE

# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/4.0/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'django-insecure-gohq_l!n&l_f76s_nq0zrbg5p!a#x#ti5=oj_%va_1@j!vzdtj'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = INSTALLED_APPS + ["debug_toolbar"]

MIDDLEWARE = ["debug_toolbar.middleware.DebugToolbarMiddleware"] + MIDDLEWARE

INTERNAL_IPS = type(str("c"), (), {"__contains__": lambda *a: True})()
