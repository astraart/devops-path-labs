#!/usr/bin/env bash
# Проверка практики «Сервис под systemd» (real.linux-system). Только читает состояние машины.
# Запуск: ./labs/real.linux-system/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.linux-system "$@"

active() { systemctl is-active --quiet demo-web; }
enabled() { systemctl is-enabled --quiet demo-web; }
page() { local out; out="$(curl -fsS -m 3 http://localhost:8000/)"; grep -qF '<h1>demo</h1>' <<<"$out"; }
restarted() { local n; n="$(systemctl show -p NRestarts --value demo-web)"; [[ "${n:-0}" -ge 1 ]]; }

check 0 "demo-web запущен (active)" active
check 1 "demo-web включён в автозапуск (enabled)" enabled
check 2 "localhost:8000 отдаёт <h1>demo</h1>" page
check 3 "после kill -9 systemd перезапустил сервис (NRestarts ≥ 1)" restarted
lab_finish
