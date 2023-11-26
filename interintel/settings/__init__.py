from os import environ

from .base import *  # noqa

if environ.setdefault("ENVIRONMENT", "PRODUCTION").upper() == "DEVELOPMENT":
    from .development import *  # noqa
else:
    from .production import *  # noqa

try:
    from .local import *  # noqa
except ImportError:
    pass
