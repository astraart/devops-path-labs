#!/usr/bin/env bash
# Проверка практики «Мониторинг молчит» (real.observability-fix).
# Только читает: docker ps и inspect, HTTP API Prometheus на 127.0.0.1:9091.
# Запуск: ./labs/real.observability-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.observability-fix "$@"

API=http://127.0.0.1:9091
dk() { docker "$@" 2>/dev/null || as_root docker "$@"; }
prom() {
    local id
    id="$(dk ps -aq --filter label=com.docker.compose.project=lab-obs-fix --filter label=com.docker.compose.service=prometheus)" || return $?
    [[ -n "$id" ]] && head -n 1 <<<"$id"
}
api() { curl -fsS -m 5 "$API$1"; }
json() { python3 -I -c "import json, sys; d = json.load(sys.stdin); sys.exit(0 if ($1) else 1)"; }

running() { local c; c="$(prom)" || return $?; [[ "$(dk inspect -f '{{.State.Status}} {{.State.Restarting}}' "$c")" == "running false" ]]; }
ready() { local out; out="$(api /-/ready)" || return 1; grep -q 'Ready' <<<"$out"; }
rule() { api /api/v1/rules | json 'any(r.get("name") == "InstanceDown" and r.get("duration") == 300 for g in d["data"]["groups"] for r in g["rules"])'; }
target() { api /api/v1/targets | json 'any(t["labels"].get("job") == "node" and t["health"] == "up" for t in d["data"]["activeTargets"])'; }
nonroot() { local c u; c="$(prom)" || return $?; u="$(dk inspect -f '{{.Config.User}}' "$c")" || return $?; [[ -n "$u" && ! "$u" =~ ^(root|0)(:.*)?$ ]]; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "контейнер prometheus работает и не перезапускается" running
check 2 "Prometheus готов: 127.0.0.1:9091/-/ready" ready
check 3 "загружено правило InstanceDown с for: 5m" rule
check 4 "цель job=\"node\" — up" target
check 5 "Prometheus по-прежнему работает не от root" nonroot
lab_finish
