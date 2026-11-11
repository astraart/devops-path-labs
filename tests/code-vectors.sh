#!/usr/bin/env bash
# Самопроверка формулы кода: те же векторы проверяет приложение (RealLabCodeTest).
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
fail=0
while read -r lab challenge mask expected; do
    got="$(lab_code "$lab" "$challenge" "$mask")"
    if [[ "$got" != "$expected" ]]; then
        echo "FAIL $lab $challenge $mask: $got != $expected"
        fail=1
    fi
done <<'VECTORS'
real.start 1234 0 0206-5014
real.start 1234 15 0206-7830
real.git 0042 3 0779-6975
real.bash 9999 65535 0467-1404
real.capstone 5071 6 1585-2404
VECTORS
exit $fail
