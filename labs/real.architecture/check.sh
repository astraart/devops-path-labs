#!/usr/bin/env bash
# Проверка практики «Две копии сервиса за балансировщиком» (real.architecture). Только читает состояние машины:
# службы, файлы настроек и ответы на GET-запросы к localhost. Ничего не создаёт.
# Запуск: ./labs/real.architecture/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.architecture "$@"

UNIT=/etc/systemd/system/notes-api@.service
both() { systemctl is-active --quiet notes-api@8081 && systemctl is-active --quiet notes-api@8082; }
config_in_env() {
    local env unit
    env="$(as_root grep -c DATABASE_URL /etc/notes-api/env)" || return $?
    unit="$(grep -c DATABASE_URL "$UNIT" || true)"
    [[ "$env" -ge 1 && "$unit" == "0" ]]
}
upstream() {
    local conf n
    conf="$(as_root nginx -T 2>/dev/null)" || return $?
    n="$(grep -cE 'server 127\.0\.0\.1:808[12]' <<<"$conf" || true)"
    [[ "$n" -ge 2 ]]
}
via_nginx() { curl -fsS -m 3 -o /dev/null http://localhost/healthz; }
shared() {
    local a b
    a="$(curl -fsS -m 3 http://localhost:8081/notes)"
    b="$(curl -fsS -m 3 http://localhost:8082/notes)"
    [[ "$a" == "$b" ]] && grep -q '"id"' <<<"$a"
}

check 0 "запущены оба экземпляра notes-api@8081 и notes-api@8082" both
check 1 "DATABASE_URL в /etc/notes-api/env, а не в unit-файле" config_in_env
check 2 "в upstream nginx оба экземпляра" upstream
check 3 "через nginx /healthz отвечает 200" via_nginx
check 4 "оба экземпляра отдают один и тот же список заметок, и он не пуст" shared
lab_finish
