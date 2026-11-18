#!/usr/bin/env bash
# Проверка практики «Мониторинг с алертом без подсказок» (real.observability-solo).
# Только читает: HTTP API Prometheus на 127.0.0.1:9090, docker ps, inspect и port.
# Запуск: ./labs/real.observability-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.observability-solo "$@"

API=http://127.0.0.1:9090
dk() { docker "$@" 2>/dev/null || as_root docker "$@"; }
cid() {
    local id
    id="$(dk ps -q --filter label=com.docker.compose.project=obs-solo --filter "label=com.docker.compose.service=$1")" || return $?
    [[ -n "$id" ]] && echo "$id"
}
api() { curl -fsS -m 5 "$API$1"; }
# json КОД_PYTHON — разобрать ответ API со стандартного входа (d — JSON), код возврата — результат проверки.
json() { python3 -I -c "import json, sys; d = json.load(sys.stdin); sys.exit(0 if ($1) else 1)"; }

ready() { local out; out="$(api /-/ready)" || return 1; grep -q 'Ready' <<<"$out"; }
bound() { local c out; c="$(cid prometheus)" || return $?; out="$(dk port "$c" 9090/tcp)" || return $?; [[ "$out" == "127.0.0.1:9090" ]]; }
node_up() { api /api/v1/targets | json '[t for t in d["data"]["activeTargets"] if t["labels"].get("job") == "node"] and all(t["health"] == "up" for t in d["data"]["activeTargets"] if t["labels"].get("job") == "node")'; }
interval() { api /api/v1/status/config | json 'any(b.split("\n")[0].strip() == "node" and "scrape_interval: 15s" in b for b in d["data"]["yaml"].split("- job_name:")[1:])'; }
rule() { api /api/v1/rules | json 'any(r.get("name") == "NodeDiskAlmostFull" and r.get("type") == "alerting" and r.get("duration") == 600 and r.get("labels", {}).get("severity") == "warning" for g in d["data"]["groups"] for r in g["rules"])'; }
# Prometheus пишет 7d как 1w.
retention() { api /api/v1/status/flags | json 'd["data"].get("storage.tsdb.retention.time") in ("7d", "1w")'; }
volume() { local c out; c="$(cid prometheus)" || return $?; out="$(dk inspect -f '{{range .Mounts}}{{.Type}} {{.Destination}}{{println}}{{end}}' "$c")" || return $?; grep -qx 'volume /prometheus' <<<"$out"; }

check 0 "Prometheus готов (/-/ready)" ready
check 1 "Prometheus опубликован только на 127.0.0.1:9090" bound
check 2 "цель job=\"node\" — up" node_up
check 3 "job node опрашивается каждые 15 секунд" interval
check 4 "загружен алерт NodeDiskAlmostFull: for 10m, severity=warning" rule
check 5 "данные хранятся 7 дней (--storage.tsdb.retention.time=7d)" retention
check 6 "TSDB — в именованном томе, смонтированном в /prometheus" volume
lab_finish
