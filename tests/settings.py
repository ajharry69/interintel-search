from interintel.settings.base import *  # noqa
from interintel.settings.development import *  # noqa

DATABASES = {
    'default': {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "interintel_test",
        "USER": "postgres",
        "PASSWORD": "p@ssw0rd1",
        "HOST": "localhost",
    }
}
