#!/usr/bin/env bash
# Проверка практики «Разбор настоящих логов» (real.linux-files). Только читает состояние машины.
# Запуск: ./labs/real.linux-files/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.linux-files "$@"

df_root() { df -h / >/dev/null; }
journal_usage() {
    local out
    out="$(journalctl --disk-usage 2>/dev/null)" || out="$(as_root journalctl --disk-usage)" || return $?
    grep -q 'take up' <<<"$out"
}

check 0 "df -h / показывает размер и свободное место" df_root
check 1 "journalctl --disk-usage сообщает размер журналов" journal_usage
lab_finish
