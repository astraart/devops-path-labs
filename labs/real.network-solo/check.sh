#!/usr/bin/env bash
# Проверка практики «Балансировщик на nginx без подсказок» (real.network-solo).
# Только читает: nginx -t, ss, запросы к localhost.
# Запуск: sudo ./labs/real.network-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.network-solo "$@"

URL=http://127.0.0.1:8085

conf_ok() { as_root nginx -t; }
enabled() { local l; l="$(readlink -f /etc/nginx/sites-enabled/lab-proxy)" || return 1; [[ "$l" == /etc/nginx/sites-available/lab-proxy ]]; }
balanced() {
    local all="" _
    for _ in 1 2 3 4; do all+="$(curl -fsS -m 3 "$URL/")" || return 1; done
    grep -q 'backend-1' <<<"$all" && grep -q 'backend-2' <<<"$all"
}
local_only() {
    local out
    out="$(ss -ltnH '( sport = :9001 or sport = :9002 )')" || return 1
    [[ "$(awk '{ print $4 }' <<<"$out" | sort -u | tr '\n' ' ')" == "127.0.0.1:9001 127.0.0.1:9002 " ]]
}
no_version() { local h; h="$(curl -fsSI -m 3 "$URL/")" || return 1; grep -Eiq '^server: nginx\s*$' <<<"$h"; }
health() { [[ "$(curl -fsS -m 3 "$URL/health")" == "ok" ]]; }

check 0 "sudo nginx -t: конфигурация без ошибок" conf_ok
check 1 "сайт lab-proxy включён: sites-enabled/lab-proxy → sites-available/lab-proxy" enabled
check 2 "запросы к 127.0.0.1:8085 расходятся на backend-1 и backend-2" balanced
check 3 "бэкенды слушают только 127.0.0.1:9001 и 127.0.0.1:9002" local_only
check 4 "заголовок Server без версии nginx (server_tokens off)" no_version
check 5 "/health отвечает ok сам nginx" health
lab_finish
