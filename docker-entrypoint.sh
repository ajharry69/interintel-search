#!/bin/sh

cpu_count=$(grep -c processor /proc/cpuinfo)
# https://docs.gunicorn.org/en/latest/design.html#how-many-workers
exec gunicorn --reload interintel.wsgi:application
