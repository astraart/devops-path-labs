#!/usr/bin/env bash
# Проверка практики «Сайт отвечает 504» (real.network-fix). Только читает: getent, nft list, ss, файлы, curl.
# Запуск: sudo ./labs/real.network-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.network-fix "$@"

resolves() { local a; a="$(getent hosts shop-backend.lab | awk '{ print $1 }')"; [[ "$a" == "127.0.0.1" ]]; }
# Ни одно правило nftables не отбрасывает порт 9010 (полный список правил читает только root).
not_dropped() {
    local rules
    rules="$(as_root nft list ruleset)" || return $?
    ! grep -Eq 'dport 9010 .*(drop|reject)' <<<"$rules"
}
listens() { local out; out="$(ss -ltnH 'sport = :9010')" || return 1; grep -q '127.0.0.1:9010' <<<"$out"; }
by_name() { grep -Eq '^\s*proxy_pass\s+http://shop-backend\.lab:9010;' /etc/nginx/sites-available/lab-shop; }
page() { local out; out="$(curl -fsS -m 5 http://127.0.0.1:8086/)"; grep -qF '<h1>lab-shop</h1>' <<<"$out"; }
enabled() { systemctl is-enabled --quiet lab-shop-backend || return 1; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "shop-backend.lab разрешается в 127.0.0.1" resolves
check 2 "nftables не отбрасывает порт 9010" not_dropped
check 3 "бэкенд слушает 127.0.0.1:9010" listens
check 4 "nginx по-прежнему ходит к бэкенду по имени shop-backend.lab:9010" by_name
check 5 "127.0.0.1:8086 отдаёт <h1>lab-shop</h1>" page
check 6 "lab-shop-backend в автозапуске" enabled
lab_finish
