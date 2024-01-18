#!/bin/sh -e

cpu_count=$(grep -c processor /proc/cpuinfo)
# https://docs.gunicorn.org/en/latest/design.html#how-many-workers
python manage.py collectstatic --noinput --verbosity 0
python manage.py migrate --noinput
exec gunicorn -b :"${PORT:-8000}" -w $(((cpu_count * 2) + 1)) --reload interintel.wsgi:application
