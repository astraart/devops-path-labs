#!/usr/bin/env bash
# Проверка практики «Роль для отчётов без подсказок» (real.databases-solo). Только читает каталог PostgreSQL:
# запросы SELECT к pg_roles, pg_default_acl и has_table_privilege от пользователя postgres.
# Запуск: sudo ./labs/real.databases-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.databases-solo "$@"

# pg БАЗА ЗАПРОС — запрос от суперпользователя postgres по сокету (peer), нужен root.
pg() { as_root runuser -u postgres -- psql -X -w -tA -d "$1" -c "$2"; }
is() { local got; got="$(pg "$1" "$2")" || return $?; [[ "$got" == "$3" ]]; }

role() { is postgres "select rolcanlogin::text || rolsuper::text || rolcreatedb::text || rolcreaterole::text from pg_roles where rolname = 'report'" "truefalsefalsefalse"; }
can_read() { is shop "select has_table_privilege('report', 'public.orders', 'SELECT')" "t"; }
no_write() { is shop "select has_table_privilege('report', 'public.orders', 'INSERT, UPDATE, DELETE, TRUNCATE')" "f"; }
defaults() {
    local n
    n="$(pg shop "select count(*) from pg_default_acl d join pg_roles r on r.oid = d.defaclrole where r.rolname = 'app' and d.defaclobjtype = 'r' and d.defaclacl::text like '%report=r/app%'")" || return $?
    [[ "$n" -ge 1 ]]
}
stmt_timeout() {
    local cfg
    cfg="$(pg postgres "select coalesce(string_agg(c, ','), '') from pg_db_role_setting s join pg_roles r on r.oid = s.setrole, unnest(s.setconfig) c where r.rolname = 'report'")" || return $?
    grep -q 'statement_timeout=30s' <<<"$cfg"
}
limit() { is postgres "select rolconnlimit from pg_roles where rolname = 'report'" "5"; }

check 0 "роль report: входит по паролю, не суперпользователь, не создаёт базы и роли" role
check 1 "report читает таблицу orders в базе shop" can_read
check 2 "report не может менять orders (INSERT, UPDATE, DELETE, TRUNCATE)" no_write
check 3 "новые таблицы роли app в shop report тоже сможет читать (ALTER DEFAULT PRIVILEGES)" defaults
check 4 "у report statement_timeout = 30s" stmt_timeout
check 5 "у report не больше 5 одновременных подключений" limit
lab_finish
