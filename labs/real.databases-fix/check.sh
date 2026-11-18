#!/usr/bin/env bash
# Проверка практики «Приложение не подключается к базе» (real.databases-fix). Только читает:
# подключение приложения с его паролем, pg_roles и файл pg_hba.conf.
# Запуск: sudo ./labs/real.databases-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.databases-fix "$@"

# app ЗАПРОС — как приложение: по TCP, с паролем lab-pass.
app() { PGPASSWORD=lab-pass PGCONNECT_TIMEOUT=3 psql -X -w -h 127.0.0.1 -U labapp -d labfix -tA -c "$1"; }
hba() { as_root runuser -u postgres -- psql -X -w -tA -c 'show hba_file'; }

# absent ШАБЛОН ФАЙЛ — строки по шаблону в файле нет (файл читается от root).
absent() { local rc=0; as_root grep -qE "$1" "$2" || rc=$?; case $rc in 1) return 0 ;; 0) return 1 ;; *) return "$rc" ;; esac; }

connects() { [[ "$(app 'select count(*) from items')" == "10" ]]; }
no_reject() { local f; f="$(hba)" || return $?; absent '^[^#]*\sreject(\s|$)' "$f"; }
# Починка через trust — не починка: войти без пароля сможет кто угодно.
no_trust() { local f; f="$(hba)" || return $?; absent '^\s*host\S*\s.*\strust(\s|$)' "$f"; }
valid() { [[ "$(app "select rolvaliduntil is null or rolvaliduntil > now() from pg_roles where rolname = 'labapp'")" == "t" ]]; }
limit() { local n; n="$(app "select rolconnlimit from pg_roles where rolname = 'labapp'")" || return 1; [[ -n "$n" && "$n" != "0" ]]; }
not_super() { [[ "$(app "select rolsuper from pg_roles where rolname = 'labapp'")" == "f" ]]; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "приложение подключается: labapp с паролем lab-pass видит 10 строк в items" connects
check 2 "в pg_hba.conf не осталось правила reject" no_reject
check 3 "в pg_hba.conf нет trust для сетевых подключений" no_trust
check 4 "пароль labapp не просрочен" valid
check 5 "у labapp лимит подключений не 0" limit
check 6 "labapp — не суперпользователь" not_super
lab_finish
