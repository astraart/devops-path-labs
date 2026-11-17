#!/usr/bin/env bash
# Проверка практики «Отчёт не находит данные» (real.linux-files-fix). Только читает файлы.
# Запуск: ./labs/real.linux-files-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.linux-files-fix "$@"

CONF=/opt/lab-files/conf/app.conf

no_cr() { [[ -f "$CONF" ]] && ! grep -q $'\r' "$CONF"; }
one_key() { local keys; keys="$(grep '^DATA_DIR=' "$CONF")"; [[ "$keys" == "DATA_DIR=/opt/lab-files/data" ]]; }
data() { local n; n="$(find /opt/lab-files/data -maxdepth 1 -name 'sales-2026-*.csv' | wc -l)"; [[ "$n" -eq 12 ]]; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "в app.conf нет концов строк Windows (\\r)" no_cr
check 2 "в app.conf одна строка DATA_DIR=/opt/lab-files/data" one_key
check 3 "все 12 файлов sales-2026-*.csv снова в /opt/lab-files/data" data
lab_finish
