#!/usr/bin/env bash
# Проверка практики «Health-check в venv по расписанию» (real.python). Только читает состояние машины.
# Запуск: ./labs/real.python/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.python "$@"

pep668() { compgen -G '/usr/lib/python3*/EXTERNALLY-MANAGED' >/dev/null; }
venv() { "$H/healthcheck/.venv/bin/python" -c 'import requests'; }
log_fresh() {
    local log="$H/healthcheck/check.log" recent
    [[ -n "$(find "$log" -mmin -15 2>/dev/null)" ]] || return 1
    recent="$(tail -3 "$log")"
    grep -q -- '-> 200' <<<"$recent"
}

check 0 "системный Python защищён от pip (PEP 668)" pep668
check 1 "в ~/healthcheck/.venv установлен requests" venv
check 2 "журнал ~/healthcheck/check.log обновлялся за 15 минут, есть ответы 200" log_fresh
lab_finish
