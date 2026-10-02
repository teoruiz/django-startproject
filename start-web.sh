#!/bin/sh
set -eu
# Apply migrations as an explicit deployment step, never concurrently in web replicas.
exec gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2 --access-logfile -
