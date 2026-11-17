#!/usr/bin/env bash
# Проверка практики «strace, lsof, tcpdump и perf на живой машине» (real.debugging). Только читает файлы,
# которые ученик сохранил в ~/debug: вывод strace, lsof и perf и запись трафика (её читает tcpdump -r).
# Запуск: ./labs/real.debugging/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.debugging "$@"

DIR="$H/debug"
enoent() { grep -q 'ENOENT' "$DIR/strace.txt"; }
listen() { grep -q 'LISTEN' "$DIR/lsof.txt" && grep -q ':8000' "$DIR/lsof.txt"; }
packets() {
    local n
    n="$(tcpdump -nn -r "$DIR/lo.pcap" 2>/dev/null | wc -l)"
    [[ "$n" -ge 3 ]]
}
reset() { tcpdump -nn -r "$DIR/lo.pcap" 2>/dev/null | grep -q 'Flags \[R'; }
taskclock() { grep -q 'task-clock' "$DIR/perf.txt"; }

check 0 "strace поймал ENOENT (debug/strace.txt)" enoent
check 1 "lsof нашёл слушающий порт 8000 (debug/lsof.txt)" listen
check 2 "в debug/lo.pcap записано не меньше 3 пакетов" packets
check 3 "в записи есть отказ соединения [R] на закрытом порту" reset
check 4 "perf stat посчитал task-clock (debug/perf.txt)" taskclock
lab_finish
