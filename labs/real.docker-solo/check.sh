#!/usr/bin/env bash
# Проверка практики «Сайт за nginx в Compose без подсказок» (real.docker-solo).
# Только читает: docker ps, inspect, port и запрос к localhost.
# Запуск: ./labs/real.docker-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.docker-solo "$@"

dk() { docker "$@" 2>/dev/null || as_root docker "$@"; }
# Контейнер службы из проекта Compose docker-solo (имя проекта — имя каталога ~/docker-solo).
cid() {
    local id
    id="$(dk ps -q --filter label=com.docker.compose.project=docker-solo --filter "label=com.docker.compose.service=$1")" || return $?
    [[ -n "$id" ]] && echo "$id"
}

healthy() { local c; c="$(cid site)" || return $?; [[ "$(dk inspect -f '{{.State.Health.Status}}' "$c")" == "healthy" ]]; }
nonroot() { local c u; c="$(cid site)" || return $?; u="$(dk inspect -f '{{.Config.User}}' "$c")" || return $?; [[ -n "$u" && ! "$u" =~ ^(root|0)(:.*)?$ ]]; }
hidden() { local c out; c="$(cid site)" || return $?; out="$(dk port "$c")" || return $?; [[ -z "$out" ]]; }
proxy_port() { local c out; c="$(cid proxy)" || return $?; out="$(dk port "$c" 80/tcp)" || return $?; [[ "$out" == "127.0.0.1:8088" ]]; }
page() { local out; out="$(curl -fsS -m 3 http://127.0.0.1:8088/)"; grep -qF 'docker-solo' <<<"$out"; }
restart() {
    local s p
    s="$(cid site)" && p="$(cid proxy)" || return $?
    [[ "$(dk inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$s" "$p" | sort -u)" == "unless-stopped" ]]
}
small() { local size; size="$(dk image inspect -f '{{.Size}}' lab/site:1.0)" || return $?; (( size < 300 * 1000 * 1000 )); }

check 0 "служба site — healthy (есть healthcheck, и он проходит)" healthy
check 1 "site работает не от root (USER в образе)" nonroot
check 2 "у site нет опубликованных портов — снаружи только через proxy" hidden
check 3 "proxy опубликован на 127.0.0.1:8088" proxy_port
check 4 "127.0.0.1:8088 отдаёт страницу со словом docker-solo" page
check 5 "у обеих служб restart: unless-stopped" restart
check 6 "образ lab/site:1.0 меньше 300 МБ (slim-база)" small
lab_finish
