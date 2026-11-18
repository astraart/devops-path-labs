#!/usr/bin/env bash
# Учебная поломка «Приложение не подключается к базе» (real.databases-fix).
# Создаёт в PostgreSQL роль labapp и базу labfix с таблицей items и ломает подключение тремя способами,
# которые сервер проверяет по очереди: правило reject в pg_hba.conf, истёкший пароль роли и лимит
# подключений 0. Пароль приложения — lab-pass, менять его нельзя: «он прописан в приложении».
# Запуск: sudo ./labs/real.databases-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.databases-fix \
"  • создаст в PostgreSQL роль labapp и базу labfix;
  • добавит в начало pg_hba.conf строку с пометкой devops-path-lab и перечитает конфигурацию;
  • изменит у labapp срок действия пароля и лимит подключений." \
"  sudo sed -i '/devops-path-lab/d' /etc/postgresql/*/main/pg_hba.conf && sudo systemctl reload postgresql
  sudo -u postgres dropdb labfix && sudo -u postgres dropuser labapp
  sudo rm /var/lib/devops-path-lab/real.databases-fix.broken"

if ! command -v pg_lsclusters >/dev/null || ! runuser -u postgres -- psql -X -tAc 'select 1' >/dev/null 2>&1; then
    echo "PostgreSQL не запущен. Сначала пройдите практику «PostgreSQL: доступы, бэкап и восстановление». Ничего не изменено." >&2
    exit 1
fi
pg() { runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 "$@"; }
if [[ "$(pg -tAc "select count(*) from pg_roles where rolname = 'labapp'")" != "0" ]]; then
    echo "Роль labapp уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi
hba="$(pg -tAc 'show hba_file')"

pg -c "CREATE ROLE labapp LOGIN PASSWORD 'lab-pass'" -c "CREATE DATABASE labfix OWNER labapp"
pg -d labfix -c "CREATE TABLE items(id serial PRIMARY KEY, name text NOT NULL); INSERT INTO items(name) SELECT 'item-' || g FROM generate_series(1, 10) g; ALTER TABLE items OWNER TO labapp"

# Поломка 1: правило reject выше остальных — pg_hba.conf читается сверху вниз до первого совпадения.
sed -i '1i host    labfix    labapp    127.0.0.1/32    reject    # devops-path-lab' "$hba"
# Поломка 2: пароль «истёк» — клиент увидит только «password authentication failed», причина — в журнале сервера.
# Поломка 3: ни одного подключения для роли.
pg -c "ALTER ROLE labapp VALID UNTIL '2026-01-01' CONNECTION LIMIT 0"
pg -tAc 'select pg_reload_conf()' > /dev/null

break_done real.databases-fix
echo "Попробуйте подключиться как приложение: PGPASSWORD=lab-pass psql -h 127.0.0.1 -U labapp -d labfix -c 'select count(*) from items'"
