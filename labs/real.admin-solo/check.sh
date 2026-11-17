#!/usr/bin/env bash
# Проверка практики «Бэкап /etc по таймеру без подсказок» (real.admin-solo). Только читает состояние:
# logrotate -d — пробный прогон, он ничего не поворачивает и не пишет файл состояния.
# Запуск: sudo ./labs/real.admin-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.admin-solo "$@"

script() { local s; s="$(stat -c '%U %a' /usr/local/sbin/etc-backup)"; [[ "${s%% *}" == "root" && -x /usr/local/sbin/etc-backup ]] && (( (8#${s##* } & 8#022) == 0 )); }
oneshot() { [[ "$(systemctl show -p Type --value etc-backup.service)" == "oneshot" ]]; }
timer() { systemctl is-active --quiet etc-backup.timer && systemctl is-enabled --quiet etc-backup.timer || return 1; }
calendar() { local c; c="$(systemctl show -p TimersCalendar --value etc-backup.timer)"; grep -qF 'OnCalendar=*-*-* 03:15:00' <<<"$c"; }
persistent() { [[ "$(systemctl show -p Persistent --value etc-backup.timer)" == "yes" ]]; }
archive() {
    local last list
    last="$(find /var/backups/etc -maxdepth 1 -name 'etc-*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -n | awk 'END { print $2 }')"
    [[ -n "$last" ]] || return 1
    list="$(as_root tar -tzf "$last")" || return $?
    grep -qx 'etc/hostname' <<<"$list"
}
rotate() {
    local f=/etc/logrotate.d/etc-backup
    grep -q '/var/log/etc-backup.log' "$f" && grep -qw weekly "$f" && grep -Eq '^\s*rotate\s+4\s*$' "$f" || return 1
    as_root logrotate -d "$f"
}
journald() { local c; c="$(systemd-analyze cat-config systemd/journald.conf)"; grep -Eq '^SystemMaxUse=200M\s*$' <<<"$c"; }

check 0 "/usr/local/sbin/etc-backup: владелец root, исполняемый, писать может только root" script
check 1 "etc-backup.service — Type=oneshot" oneshot
check 2 "etc-backup.timer запущен и включён" timer
check 3 "таймер срабатывает каждый день в 03:15" calendar
check 4 "Persistent=true — пропущенный запуск догоняется после включения машины" persistent
check 5 "в /var/backups/etc есть архив etc-*.tar.gz, и он читается (внутри etc/hostname)" archive
check 6 "logrotate для /var/log/etc-backup.log: weekly, rotate 4, logrotate -d без ошибок" rotate
check 7 "journald ограничен: SystemMaxUse=200M" journald
lab_finish
