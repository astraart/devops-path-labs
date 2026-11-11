#!/usr/bin/env bash
# Проверка практики «Prometheus + Grafana в Docker Compose» (real.observability). Только читает состояние машины.
# Запуск: ./labs/real.observability/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.observability "$@"

ready() { local out; out="$(curl -fsS -m 3 http://localhost:9090/-/ready)"; grep -q 'Ready' <<<"$out"; }
target_up() { local out; out="$(curl -fsS -m 3 http://localhost:9090/api/v1/targets)"; grep -q '"health":"up"' <<<"$out"; }

check 0 "Prometheus готов (localhost:9090/-/ready)" ready
check 1 "в Prometheus есть цель в состоянии up" target_up
manual "дашборд Grafana: графики CPU, памяти и диска заполнены"
lab_finish
