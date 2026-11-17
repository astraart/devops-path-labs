#!/usr/bin/env bash
# Учебная поломка «Сервис не стартует» (real.linux-system-fix).
# Ставит сервис lab-web (python3 -m http.server на 127.0.0.1:8081) и ломает его двумя способами:
# каталог сервиса закрыт для пользователя, от которого он работает, а порт заранее занял другой сервис.
# Запуск: sudo ./labs/real.linux-system-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.linux-system-fix \
"  • создаст каталоги /opt/lab-web и /opt/lab-squatter со страницами;
  • создаст, включит и запустит сервисы lab-web и lab-squatter (/etc/systemd/system)." \
"  sudo systemctl disable --now lab-web lab-squatter
  sudo rm /etc/systemd/system/lab-web.service /etc/systemd/system/lab-squatter.service
  sudo systemctl daemon-reload
  sudo rm -r /opt/lab-web /opt/lab-squatter /var/lib/devops-path-lab/real.linux-system-fix.broken"

if [[ -e /etc/systemd/system/lab-web.service ]]; then
    echo "Сервис lab-web уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi

mkdir -p /opt/lab-web /opt/lab-squatter
echo '<h1>lab-web</h1>' > /opt/lab-web/index.html
echo '<h1>squatter</h1>' > /opt/lab-squatter/index.html
# Поломка 1: каталог доступен только root, а сервис работает от nobody.
chmod 700 /opt/lab-web

cat > /etc/systemd/system/lab-web.service <<'UNIT'
[Unit]
Description=Lab web (DevOps Path)
After=network.target

[Service]
User=nobody
WorkingDirectory=/opt/lab-web
ExecStart=/usr/bin/python3 -m http.server 8081 --bind 127.0.0.1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

# Поломка 2: тот же порт занимает другой сервис, который ещё и стоит в автозапуске.
cat > /etc/systemd/system/lab-squatter.service <<'UNIT'
[Unit]
Description=Lab helper (DevOps Path)
After=network.target

[Service]
User=nobody
WorkingDirectory=/opt/lab-squatter
ExecStart=/usr/bin/python3 -m http.server 8081 --bind 127.0.0.1
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now lab-squatter
# lab-web упадёт при запуске — так и задумано, ошибку не считаем ошибкой скрипта.
systemctl enable --now lab-web || true

break_done real.linux-system-fix
echo "Посмотрите, что с сервисом: systemctl status lab-web"
