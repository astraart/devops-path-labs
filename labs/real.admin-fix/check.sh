#!/usr/bin/env bash
# Проверка практики «Куда делось место на диске» (real.admin-fix). Только читает состояние машины.
# Запуск: sudo ./labs/real.admin-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.admin-fix "$@"

OLD=/var/log/lab-app/old/debug.log.1

old_gone() { [[ ! -e "$OLD" ]] || (( $(stat -c %s "$OLD") < 1024 * 1024 )); }
# Никто не держит открытыми удалённые файлы из /var/log/lab-app (ссылки в /proc/PID/fd с пометкой «(deleted)»).
no_deleted() {
    local out rc=0
    out="$(as_root find /proc -mindepth 3 -maxdepth 3 -path '/proc/[0-9]*/fd/*' -lname '/var/log/lab-app/*(deleted)' 2>/dev/null)" || rc=$?
    [[ $rc -eq 3 ]] && return 3
    [[ -z "$out" ]]
}
active() { systemctl is-active --quiet lab-hog || return 1; }
fresh_log() { [[ -f /var/log/lab-app/current.log ]]; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "старый debug.log.1 на 400 МБ удалён или очищен" old_gone
check 2 "никто не держит открытыми удалённые файлы из /var/log/lab-app" no_deleted
check 3 "lab-hog работает — приложение не выключили, чтобы освободить место" active
check 4 "lab-hog снова пишет в /var/log/lab-app/current.log" fresh_log
lab_finish
