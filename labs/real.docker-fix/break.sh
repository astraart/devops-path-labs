#!/usr/bin/env bash
# Учебная поломка «Контейнер перезапускается по кругу» (real.docker-fix).
# Собирает из уже скачанного образа python:3.12-slim маленький счётчик посещений и запускает его
# в Compose с тремя ошибками: опечатка в переменной окружения, не тот порт контейнера и том,
# в который пользователь приложения не может писать. Ничего не скачивает.
# Запуск: sudo ./labs/real.docker-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.docker-fix \
"  • создаст каталог /opt/lab-docker-fix: app.py, Dockerfile, compose.yaml;
  • соберёт образ lab/counter:1.0 и запустит проект Compose lab-docker-fix с томом counter-data." \
"  sudo docker compose -f /opt/lab-docker-fix/compose.yaml down -v --rmi local
  sudo rm -r /opt/lab-docker-fix /var/lib/devops-path-lab/real.docker-fix.broken"

if ! docker info >/dev/null 2>&1; then
    echo "Docker Engine не отвечает. Сначала пройдите практику «Docker Engine, свой образ и Compose». Ничего не изменено." >&2
    exit 1
fi
# Скрипт ничего не скачивает: базовый образ должен быть уже на машине.
if ! docker image inspect python:3.12-slim >/dev/null 2>&1; then
    echo "Нет образа python:3.12-slim. Он скачивается в практике «Docker Engine, свой образ и Compose»" >&2
    echo "(или: docker pull python:3.12-slim). Ничего не изменено." >&2
    exit 1
fi
if [[ -e /opt/lab-docker-fix ]]; then
    echo "Каталог /opt/lab-docker-fix уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi

mkdir -p /opt/lab-docker-fix
cat > /opt/lab-docker-fix/app.py <<'PY'
"""Счётчик посещений для учебной поломки real.docker-fix: хранит число в $DATA_DIR/visits.txt."""
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

DATA_DIR = os.environ.get("DATA_DIR", "")
if not os.path.isdir(DATA_DIR):
    print(f"ERROR: DATA_DIR={DATA_DIR!r} is not a directory", file=sys.stderr, flush=True)
    sys.exit(1)
COUNTER = os.path.join(DATA_DIR, "visits.txt")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            n = 1
            if os.path.exists(COUNTER):
                with open(COUNTER) as f:
                    n = int(f.read() or 0) + 1
            with open(COUNTER, "w") as f:
                f.write(str(n))
        except OSError as e:
            print(f"ERROR: cannot write {COUNTER}: {e}", file=sys.stderr, flush=True)
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b"error\n")
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(f"visits: {n}\n".encode())


print("listening on 0.0.0.0:8000", flush=True)
HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
PY

cat > /opt/lab-docker-fix/Dockerfile <<'DOCKERFILE'
FROM python:3.12-slim
RUN useradd --system --uid 10001 app
COPY app.py /app/app.py
USER app
CMD ["python", "/app/app.py"]
DOCKERFILE

cat > /opt/lab-docker-fix/compose.yaml <<'YAML'
name: lab-docker-fix
services:
  web:
    build: .
    image: lab/counter:1.0
    environment:
      DATA_DIR: /date
    volumes:
      - counter-data:/data
    ports:
      - "127.0.0.1:8082:8080"
    restart: unless-stopped
volumes:
  counter-data:
YAML

docker compose -f /opt/lab-docker-fix/compose.yaml up -d --build --pull never

break_done real.docker-fix
echo "Посмотрите: docker compose -f /opt/lab-docker-fix/compose.yaml ps  и  curl -s 127.0.0.1:8082"
