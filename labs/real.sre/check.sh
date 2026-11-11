#!/usr/bin/env bash
# Проверка практики «SLO, учебная авария и постмортем» (real.sre). Только читает состояние машины.
# Запуск: ./labs/real.sre/check.sh ЧИСЛО [ПУТЬ_К_POSTMORTEM.md]
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.sre "$@"

PM="${2:-}"
find_pm() {
    if [[ -n "$PM" ]]; then printf '%s' "$PM"; return; fi
    find "$H" -maxdepth 3 -name postmortem.md -print -quit 2>/dev/null
}
timeline() {
    local f n
    f="$(find_pm)"
    [[ -n "$f" && -f "$f" ]] || return 1
    n="$(grep -cE '[0-2][0-9]:[0-5][0-9]' "$f")"
    [[ "$n" -ge 2 ]]
}

check 0 "postmortem.md с хронологией (не меньше двух отметок времени)" timeline
manual "алерт сработал при остановке nginx и погас после восстановления"
lab_finish
