#!/usr/bin/env bash
# Установка на сервер: скрипты — в /opt/server-automation, конфиг — в /etc/server-automation,
# юниты — в /etc/systemd/system, таймеры включаются сразу.
# Повторный запуск безопасен: обновляет скрипты и юниты, но не трогает уже настроенный config.env.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Запустите через sudo: sudo ./install.sh" >&2
    exit 1
fi
cd "$(dirname "$0")"

install -d -m 0755 /opt/server-automation/bin
install -m 0755 bin/backup.sh bin/rotate.sh bin/healthcheck.py bin/report.py /opt/server-automation/bin/
install -m 0644 README.md /opt/server-automation/README.md

# Бэкапы и состояние содержат копии /etc — доступ только root.
install -d -m 0700 /etc/server-automation /var/backups/server-automation /var/lib/server-automation
if [[ ! -f /etc/server-automation/config.env ]]; then
    install -m 0600 config.env.example /etc/server-automation/config.env
    echo "Создан /etc/server-automation/config.env — проверьте адреса в HEALTH_URLS."
fi

install -m 0644 systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now server-automation-backup.timer server-automation-health.timer server-automation-report.timer
systemctl list-timers 'server-automation-*' --no-pager
