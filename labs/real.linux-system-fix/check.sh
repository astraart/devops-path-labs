#!/usr/bin/env bash
# Проверка практики «Сервис не стартует» (real.linux-system-fix). Только читает состояние машины.
# Запуск: ./labs/real.linux-system-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.linux-system-fix "$@"

active() { systemctl is-active --quiet lab-web || return 1; }
enabled() { systemctl is-enabled --quiet lab-web || return 1; }
page() { local out; out="$(curl -fsS -m 3 http://127.0.0.1:8081/)"; grep -qF '<h1>lab-web</h1>' <<<"$out"; }
# Помеха убрана насовсем: не работает и не поднимется после перезагрузки.
squatter() { ! systemctl is-active --quiet lab-squatter && ! systemctl is-enabled --quiet lab-squatter; }
# chmod 777 — не починка: писать в каталог сайта могут все.
not_open() { local mode; mode="$(stat -c '%a' /opt/lab-web)"; (( (8#$mode & 8#002) == 0 )); }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "lab-web запущен (active)" active
check 2 "lab-web включён в автозапуск (enabled)" enabled
check 3 "127.0.0.1:8081 отдаёт <h1>lab-web</h1>, а не чужую страницу" page
check 4 "lab-squatter остановлен и убран из автозапуска" squatter
check 5 "/opt/lab-web не открыт на запись всем (не 777)" not_open
lab_finish
