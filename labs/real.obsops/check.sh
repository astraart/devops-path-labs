#!/usr/bin/env bash
# Проверка практики «Алерты под тестами, Alertmanager и Loki» (real.obsops). Только читает состояние машины.
# Запуск: ./labs/real.obsops/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.obsops "$@"

M="$H/mon"
# promtool и amtool — только если установлены локально (контейнеры скрипт не запускает)
rules() { command -v promtool >/dev/null || return 3; (cd "$M" && promtool test rules tests.yml); }
routes() {
    command -v amtool >/dev/null || return 3
    local out
    out="$(amtool config routes test --config.file="$M/alertmanager.yml" severity=critical team=db)"
    grep -q 'db-team' <<<"$out"
}
metrics() { local out n; out="$(curl -fsS -m 3 http://localhost:9100/metrics)"; n="$(grep -c '^node_' <<<"$out")"; [[ "$n" -ge 100 ]]; }
loki() {
    local out
    out="$(curl -fsS -m 5 -G http://localhost:3100/loki/api/v1/query_range --data-urlencode 'query={app="shop"} | json | status >= 500')"
    grep -q '500' <<<"$out" && grep -q '502' <<<"$out"
}

check 0 "promtool test rules tests.yml — SUCCESS" rules
check 1 "amtool: severity=critical team=db уходит в db-team" routes
check 2 "node-exporter на localhost:9100 отдаёт сотни метрик node_*" metrics
check 3 "Loki находит строки со статусами 500 и 502" loki
echo
echo "promtool и amtool в контейнерах скрипт не запускает: если они помечены «?», проверьте их командами из практики."
lab_finish
