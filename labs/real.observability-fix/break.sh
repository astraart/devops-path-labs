#!/usr/bin/env bash
# Учебная поломка «Мониторинг молчит» (real.observability-fix).
# Поднимает в Compose Prometheus и node_exporter из уже скачанных образов и ломает их тремя способами:
# каталог данных на диске хоста недоступен пользователю Prometheus, в файле правил ошибка, а цель
# опрашивается не на том порту. Ничего не скачивает.
# Запуск: sudo ./labs/real.observability-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.observability-fix \
"  • создаст каталог /opt/lab-obs-fix: compose.yaml, prometheus.yml, alerts.yml и data/;
  • запустит проект Compose lab-obs-fix (Prometheus на 127.0.0.1:9091 и node_exporter)." \
"  sudo docker compose -f /opt/lab-obs-fix/compose.yaml down
  sudo rm -r /opt/lab-obs-fix /var/lib/devops-path-lab/real.observability-fix.broken"

if ! docker info >/dev/null 2>&1; then
    echo "Docker Engine не отвечает. Сначала пройдите практику модуля Docker. Ничего не изменено." >&2
    exit 1
fi
# Скрипт ничего не скачивает: берёт образы, которые уже есть (их скачивает практика «Prometheus + Grafana»).
prom="$(docker image ls prom/prometheus --format '{{.Repository}}:{{.Tag}}' | grep -v ':<none>$' | head -n 1)" || true
node="$(docker image ls prom/node-exporter --format '{{.Repository}}:{{.Tag}}' | grep -v ':<none>$' | head -n 1)" || true
if [[ -z "$prom" || -z "$node" ]]; then
    echo "Нет образов prom/prometheus и prom/node-exporter. Они скачиваются в практике «Prometheus + Grafana в Docker Compose»." >&2
    echo "Ничего не изменено." >&2
    exit 1
fi
if [[ -e /opt/lab-obs-fix ]]; then
    echo "Каталог /opt/lab-obs-fix уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi

mkdir -p /opt/lab-obs-fix/data
# Поломка 1: каталог данных принадлежит root, а Prometheus в образе работает от nobody.
chmod 755 /opt/lab-obs-fix/data

# Поломка 2: цель опрашивается на 9101, а node_exporter слушает 9100.
cat > /opt/lab-obs-fix/prometheus.yml <<'YAML'
global:
  scrape_interval: 15s
rule_files:
  - /etc/prometheus/alerts.yml
scrape_configs:
  - job_name: node
    static_configs:
      - targets: ["node-exporter:9101"]
YAML

# Поломка 3: «5 minutes» — не длительность Prometheus (нужно 5m).
cat > /opt/lab-obs-fix/alerts.yml <<'YAML'
groups:
  - name: availability
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5 minutes
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} не отвечает"
YAML

cat > /opt/lab-obs-fix/compose.yaml <<YAML
name: lab-obs-fix
services:
  prometheus:
    image: $prom
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./alerts.yml:/etc/prometheus/alerts.yml:ro
      - ./data:/prometheus
    ports:
      - "127.0.0.1:9091:9090"
    restart: unless-stopped
  node-exporter:
    image: $node
    restart: unless-stopped
YAML

docker compose -f /opt/lab-obs-fix/compose.yaml up -d --pull never

break_done real.observability-fix
echo "Посмотрите: docker compose -f /opt/lab-obs-fix/compose.yaml ps  и  curl -s 127.0.0.1:9091/-/ready"
