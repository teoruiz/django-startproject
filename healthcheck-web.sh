#!/bin/sh
set -eu
exec python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/', timeout=3)"
