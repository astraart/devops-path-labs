#!/usr/bin/env bash
# Учебная поломка «Сайт отвечает 504» (real.network-fix).
# Ставит маленький магазин: бэкенд lab-shop-backend (python3 -m http.server) и сайт nginx на 127.0.0.1:8086,
# который ходит к бэкенду по имени shop-backend.lab:9010. Ломает цепочку в трёх местах: имя в /etc/hosts
# указывает не туда, отдельная таблица nftables отбрасывает пакеты на порт 9010, а бэкенд слушает не тот порт.
# Запуск: sudo ./labs/real.network-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.network-fix \
"  • создаст /opt/lab-shop и сервис lab-shop-backend;
  • добавит сайт nginx lab-shop (sites-available и ссылка в sites-enabled) и перезагрузит nginx;
  • допишет в /etc/hosts строку с пометкой devops-path-lab;
  • добавит таблицу nftables inet lab_guard (не сохраняется после перезагрузки)." \
"  sudo systemctl disable --now lab-shop-backend && sudo rm /etc/systemd/system/lab-shop-backend.service && sudo systemctl daemon-reload
  sudo rm /etc/nginx/sites-enabled/lab-shop /etc/nginx/sites-available/lab-shop && sudo systemctl reload nginx
  sudo sed -i '/devops-path-lab/d' /etc/hosts
  sudo nft delete table inet lab_guard 2>/dev/null || true
  sudo rm -r /opt/lab-shop /var/lib/devops-path-lab/real.network-fix.broken"

if ! command -v nginx >/dev/null; then
    echo "Нет nginx. Сначала пройдите практику «nginx, firewall и HTTPS». Ничего не изменено." >&2
    exit 1
fi
if ! command -v nft >/dev/null; then
    echo "Нет утилиты nft: sudo apt install nftables. Ничего не изменено." >&2
    exit 1
fi
if [[ -e /etc/nginx/sites-available/lab-shop ]]; then
    echo "Сайт lab-shop уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi

mkdir -p /opt/lab-shop
echo '<h1>lab-shop</h1>' > /opt/lab-shop/index.html

# Поломка 1: бэкенд слушает 9011, а nginx ждёт его на 9010.
cat > /etc/systemd/system/lab-shop-backend.service <<'UNIT'
[Unit]
Description=Lab shop backend (DevOps Path)
After=network.target

[Service]
User=nobody
WorkingDirectory=/opt/lab-shop
ExecStart=/usr/bin/python3 -m http.server 9011 --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now lab-shop-backend

cat > /etc/nginx/sites-available/lab-shop <<'NGINX'
server {
    listen 127.0.0.1:8086;
    location / {
        proxy_pass http://shop-backend.lab:9010;
        proxy_connect_timeout 3s;
    }
}
NGINX
ln -s /etc/nginx/sites-available/lab-shop /etc/nginx/sites-enabled/lab-shop

# Поломка 2: имя бэкенда указывает на адрес из документационного диапазона — туда никто не ответит.
echo "192.0.2.10    shop-backend.lab    # devops-path-lab" >> /etc/hosts

# Поломка 3: «временное» правило, которое забыли убрать.
nft -f - <<'NFT'
table inet lab_guard {
    chain input {
        type filter hook input priority filter; policy accept;
        tcp dport 9010 drop comment "temporary block"
    }
}
NFT

nginx -t
systemctl reload nginx

break_done real.network-fix
echo "Проверьте: curl -sv http://127.0.0.1:8086/"
