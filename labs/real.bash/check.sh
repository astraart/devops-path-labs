#!/usr/bin/env bash
# Проверка практики «Бэкап-скрипт с ротацией и cron» (real.bash). Только читает состояние машины.
# Запуск: ./labs/real.bash/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.bash "$@"

D=/var/backups/etc-lab
latest() { local f; f="$(compgen -G "$D/etc-*.tar.gz" | sort | tail -1)"; [[ -n "$f" ]] && printf '%s' "$f"; }
backups() { latest >/dev/null || as_root test -n "$(compgen -G "$D/etc-*.tar.gz")"; }
readable() {
    local f list
    f="$(latest)" || return 1
    list="$(tar -tzf "$f" 2>/dev/null)" || list="$(as_root tar -tzf "$f")" || return $?
    grep -q '^etc/' <<<"$list"
}
cron() { local out; out="$(as_root crontab -l -u root)" || return $?; grep -qF '/usr/local/bin/backup-etc.sh' <<<"$out"; }
lint() { command -v shellcheck >/dev/null && shellcheck /usr/local/bin/backup-etc.sh; }

check 0 "в $D есть архивы etc-ДАТА.tar.gz" backups
check 1 "последний архив читается и содержит etc/" readable
check 2 "в crontab root есть запуск /usr/local/bin/backup-etc.sh" cron
check 3 "shellcheck не находит замечаний в backup-etc.sh" lint
lab_finish
