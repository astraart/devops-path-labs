#!/usr/bin/env bash
# Проверка практики «Сервис от своего пользователя без подсказок» (real.linux-system-solo).
# Только читает состояние машины.
# Запуск: ./labs/real.linux-system-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.linux-system-solo "$@"

# Системный пользователь: UID меньше 1000, войти под ним нельзя.
user() {
    local line uid shell
    line="$(getent passwd notes)"
    uid="$(cut -d: -f3 <<<"$line")"
    shell="$(cut -d: -f7 <<<"$line")"
    [[ "$uid" -lt 1000 && "$shell" =~ (nologin|false)$ ]]
}
dir() { local s; s="$(stat -c '%U:%G %a' /srv/notes)"; [[ "$s" == "notes:notes 750" ]]; }
active() { systemctl is-active --quiet notes-web || return 1; }
enabled() { systemctl is-enabled --quiet notes-web || return 1; }
runs_as() { local pid u; pid="$(systemctl show -p MainPID --value notes-web)"; [[ "$pid" -gt 0 ]] && u="$(ps -o user= -p "$pid")" && [[ "${u// /}" == "notes" ]]; }
page() { local out; out="$(curl -fsS -m 3 http://127.0.0.1:8090/)"; grep -qF '<h1>notes</h1>' <<<"$out"; }
restart() { [[ "$(systemctl show -p Restart --value notes-web)" == "on-failure" ]]; }

check 0 "системный пользователь notes: UID < 1000, оболочка nologin" user
check 1 "/srv/notes: владелец notes:notes, права 750" dir
check 2 "notes-web запущен (active)" active
check 3 "notes-web включён в автозапуск (enabled)" enabled
check 4 "процесс сервиса работает от пользователя notes" runs_as
check 5 "127.0.0.1:8090 отдаёт <h1>notes</h1>" page
check 6 "Restart=on-failure — systemd поднимет упавший сервис" restart
lab_finish
