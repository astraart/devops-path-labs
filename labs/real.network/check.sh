#!/usr/bin/env bash
# Проверка практики «nginx, firewall и HTTPS» (real.network). Только читает состояние машины.
# Запуск: ./labs/real.network/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.network "$@"

ufw_ok() {
    local out
    out="$(as_root ufw status)" || return $?
    grep -q 'Status: active' <<<"$out" && grep -q 'OpenSSH' <<<"$out" && grep -q 'Nginx Full' <<<"$out"
}
nginx_ok() { as_root nginx -t; }
http_ok() { local out; out="$(curl -fsSI -m 3 http://localhost/)"; grep -q '^HTTP/[0-9.]* 200' <<<"$out"; }

check 0 "ufw включён, разрешены OpenSSH и Nginx Full" ufw_ok
check 1 "nginx -t: конфигурация в порядке" nginx_ok
check 2 "nginx отвечает 200 на http://localhost/" http_ok
manual "dig +short ВАШ_ДОМЕН возвращает IP сервера"
manual "curl -sI https://ВАШ_ДОМЕН | head -1 — HTTP/2 200"
lab_finish
