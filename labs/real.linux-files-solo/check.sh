#!/usr/bin/env bash
# Проверка практики «Отчёт по логу без подсказок» (real.linux-files-solo). Только читает файлы.
# Правильные ответы скрипт считает сам — из access.log рядом с ним, тем же способом, что и в уроках.
# Запуск: ./labs/real.linux-files-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.linux-files-solo "$@"

LOG="$(dirname "$0")/access.log"
R="$H/reports"

# Пробелы в начале строки и между полями не важны: uniq -c выравнивает числа пробелами.
norm() { awk '{ $1 = $1; print }'; }
same() { [[ -f "$2" ]] && [[ "$(norm < "$2")" == "$1" ]]; }

top_ip() { same "$(awk '{ print $1 }' "$LOG" | sort | uniq -c | sort -rn | awk 'NR <= 5' | norm)" "$R/top-ip.txt"; }
errors() { same "$(awk '$9 >= 500 && $9 <= 599 { n++ } END { print n + 0 }' "$LOG")" "$R/5xx.txt"; }
top404() { same "$(awk '$9 == 404 { print $7 }' "$LOG" | sort | uniq -c | sort -rn | awk 'NR == 1 { print $2 }')" "$R/top-404.txt"; }
slow() { same "$(awk '$NF > 1 { n++ } END { print n + 0 }' "$LOG")" "$R/slow.txt"; }

check 0 "top-ip.txt: пять IP с наибольшим числом запросов, «число IP», по убыванию" top_ip
check 1 "5xx.txt: число ответов с кодом 500–599" errors
check 2 "top-404.txt: путь, который чаще всех отвечал 404" top404
check 3 "slow.txt: число запросов дольше секунды (последнее поле — время ответа)" slow
lab_finish
