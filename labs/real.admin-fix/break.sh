#!/usr/bin/env bash
# Учебная поломка «Куда делось место на диске» (real.admin-fix).
# Занимает около 700 МБ двумя способами, которые часто встречаются вместе:
#   • старый лог /var/log/lab-app/old/debug.log.1 на 400 МБ;
#   • лог на 300 МБ, который удалили, но сервис lab-hog держит его открытым — место не освобождается,
#     а du его уже не видит.
# Запуск: sudo ./labs/real.admin-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.admin-fix \
"  • займёт около 700 МБ в /var/log/lab-app;
  • создаст, включит и запустит сервис lab-hog (/etc/systemd/system/lab-hog.service,
    программа /usr/local/libexec/lab-hog.py)." \
"  sudo systemctl disable --now lab-hog
  sudo rm /etc/systemd/system/lab-hog.service /usr/local/libexec/lab-hog.py
  sudo systemctl daemon-reload
  sudo rm -r /var/log/lab-app /var/lib/devops-path-lab/real.admin-fix.broken"

if [[ -e /etc/systemd/system/lab-hog.service ]]; then
    echo "Сервис lab-hog уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi
# Не занимать последнее место: нужно хотя бы 2 ГБ свободных на /var/log.
avail_kb="$(df --output=avail -k /var/log | tail -n 1)"
if (( avail_kb < 2 * 1024 * 1024 )); then
    echo "На диске меньше 2 ГБ свободного места — поломка заняла бы последнее. Ничего не изменено." >&2
    exit 1
fi

mkdir -p /var/log/lab-app/old
# Поломка 1: забытый большой лог.
dd if=/dev/zero of=/var/log/lab-app/old/debug.log.1 bs=1M count=400 status=none

# «Приложение»: держит свой лог открытым и раз в 10 секунд дописывает строку.
mkdir -p /usr/local/libexec
cat > /usr/local/libexec/lab-hog.py <<'PY'
#!/usr/bin/env python3
"""Сервис для учебной поломки real.admin-fix: пишет в /var/log/lab-app/current.log, не закрывая файл."""
import time

with open("/var/log/lab-app/current.log", "a", buffering=1) as log:
    while True:
        log.write(time.strftime("%Y-%m-%dT%H:%M:%S lab-hog: ok\n"))
        time.sleep(10)
PY
chmod 755 /usr/local/libexec/lab-hog.py

cat > /etc/systemd/system/lab-hog.service <<'UNIT'
[Unit]
Description=Lab hog (DevOps Path)

[Service]
ExecStart=/usr/bin/python3 /usr/local/libexec/lab-hog.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

# Поломка 2: лог на 300 МБ, который сервис держит открытым…
dd if=/dev/zero of=/var/log/lab-app/current.log bs=1M count=300 status=none
systemctl daemon-reload
systemctl enable --now lab-hog
sleep 2
# …а его «почистили» обычным rm. Файл исчез из каталога, но место занято, пока процесс жив.
rm /var/log/lab-app/current.log

break_done real.admin-fix
echo "Сравните: df -h /  и  sudo du -sh /var/log"
