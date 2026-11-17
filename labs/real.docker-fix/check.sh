#!/usr/bin/env bash
# Проверка практики «Контейнер перезапускается по кругу» (real.docker-fix).
# Только читает: docker ps, inspect и запрос к localhost.
# Запуск: ./labs/real.docker-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.docker-fix "$@"

dk() { docker "$@" 2>/dev/null || as_root docker "$@"; }
web() {
    local id
    id="$(dk ps -aq --filter label=com.docker.compose.project=lab-docker-fix --filter label=com.docker.compose.service=web)" || return $?
    [[ -n "$id" ]] && head -n 1 <<<"$id"
}

running() { local c; c="$(web)" || return $?; [[ "$(dk inspect -f '{{.State.Status}} {{.State.Restarting}}' "$c")" == "running false" ]]; }
env_ok() { local c out; c="$(web)" || return $?; out="$(dk inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c")" || return $?; grep -qx 'DATA_DIR=/data' <<<"$out"; }
counter() { local out; out="$(curl -fsS -m 3 http://127.0.0.1:8082/)"; [[ "$out" =~ ^visits:\ [0-9]+ ]]; }
nonroot() { local c u; c="$(web)" || return $?; u="$(dk inspect -f '{{.Config.User}}' "$c")" || return $?; [[ -n "$u" && ! "$u" =~ ^(root|0)(:.*)?$ ]]; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "контейнер web работает и не перезапускается" running
check 2 "в контейнере DATA_DIR=/data" env_ok
check 3 "127.0.0.1:8082 отвечает «visits: N» — порт верный, счётчик пишется в том" counter
check 4 "приложение по-прежнему работает не от root" nonroot
lab_finish
