#!/usr/bin/env bash
# Проверка практики «PostgreSQL: доступы, бэкап и восстановление» (real.databases). Только читает состояние машины.
# Запуск: ./labs/real.databases/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.databases "$@"

q() { PGCONNECT_TIMEOUT=3 psql -w -h localhost -U app -tA "$@"; }
restored() {
    local n
    n="$(q -d shop_check -c 'select count(*) from orders')" || { [[ -z "${PGPASSWORD:-}" ]] && return 3; return 1; }
    [[ "$n" == "1000" ]]
}
dump() { local out; out="$(pg_restore -l "$H/pgbackup/shop.dump")"; grep -q 'Format: CUSTOM' <<<"$out"; }
not_super() { local s; s="$(q -d shop -c "select rolsuper from pg_roles where rolname = 'app'")"; [[ "$s" == "f" ]]; }

check 0 "в shop_check восстановлено 1000 заказов" restored
check 1 "файл ~/pgbackup/shop.dump — дамп в формате custom" dump
check 2 "роль app без прав суперпользователя" not_super
if [[ -z "${PGPASSWORD:-}" ]]; then
    echo
    echo "Если проверка shop_check помечена «?» или «✗» из-за пароля: PGPASSWORD=change-me $0 $CHALLENGE"
fi
lab_finish
