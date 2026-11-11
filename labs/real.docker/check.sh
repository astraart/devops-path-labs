#!/usr/bin/env bash
# Проверка практики «Docker Engine, свой образ и Compose» (real.docker). Только читает состояние машины.
# Запуск: ./labs/real.docker/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.docker "$@"

APP="$H/app"
dk() { docker "$@" 2>/dev/null || as_root docker "$@"; }
server() { local v; v="$(dk version --format '{{.Server.Version}}')" || return $?; [[ -n "$v" ]]; }
compose() {
    local out
    out="$(dk compose --project-directory "$APP" ps --format '{{.Service}} {{.State}} {{.Health}}')" || return $?
    grep -q '^web running' <<<"$out" && grep -q '^db running healthy' <<<"$out"
}
page() { local out; out="$(curl -fsS -m 3 http://localhost:8000/)"; grep -qF '<h1>hello from container</h1>' <<<"$out"; }
image() { local out; out="$(dk images --format '{{.Repository}}')" || return $?; grep -qx 'lab/web' <<<"$out"; }

check 0 "Docker Engine отвечает (docker version)" server
check 1 "docker compose ps: web — running, db — running (healthy)" compose
check 2 "localhost:8000 отдаёт <h1>hello from container</h1>" page
check 3 "собран образ lab/web" image
lab_finish
