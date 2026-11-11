#!/usr/bin/env bash
# Проверка практики «Диски, LVM, таймер и logrotate» (real.admin). Только читает состояние машины.
# Запуск: ./labs/real.admin/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.admin "$@"

lv_size() {
    local out
    out="$(as_root lvs --noheadings --units g --nosuffix -o lv_size vglab/data)" || return $?
    awk '{ exit !($1 >= 3.5) }' <<<"$out"
}
mounted() { local src; src="$(findmnt -n -o SOURCE /mnt/lab)"; grep -q 'vglab-data' <<<"$src"; }
timer() { systemctl is-active --quiet lab-stamp.timer; }
rotated() { [[ -e /var/log/lab/stamp.log ]] && compgen -G '/var/log/lab/stamp.log.1*' >/dev/null; }

check 0 "логический том vglab/data около 4 ГБ" lv_size
check 1 "/mnt/lab смонтирован из /dev/mapper/vglab-data" mounted
check 2 "таймер lab-stamp.timer активен" timer
check 3 "logrotate повернул журнал: stamp.log и stamp.log.1" rotated
lab_finish
