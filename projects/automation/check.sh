#!/usr/bin/env bash
# Проверка проекта 1 «Автоматизация сервера» (project.automation). Только читает:
# репозиторий ученика (git, файлы, shellcheck) и состояние сервера (таймеры, бэкапы, отчёты).
# Запуск: ./projects/automation/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]   (по умолчанию ~/server-automation)
# Бэкапы и состояние доступны только root — для проверок 9–12 запустите через sudo.
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init project.automation "$@"

REPO="${2:-$H/server-automation}"
STARTER="$(dirname "$0")/starter"
B=/var/backups/server-automation
STATE=/var/lib/server-automation
echo "Репозиторий: $REPO"
echo

git_ok() {
    local n dirty
    n="$(as_user git -C "$REPO" rev-list --count HEAD)" || return 1
    # --no-optional-locks: git status не обновляет индекс, то есть ничего не пишет.
    dirty="$(as_user git --no-optional-locks -C "$REPO" status --porcelain)" || return 1
    [[ "$n" -ge 5 && -z "$dirty" ]]
}

readme_ok() {
    local f="$REPO/README.md" sections
    [[ -f "$f" ]] || return 1
    sections="$(grep -c '^## ' "$f")" || return 1
    [[ "$sections" -ge 4 ]] && grep -q '[Вв]осстанов' "$f" && ! grep -q 'TODO' "$f"
}

implemented_ok() {
    [[ -d "$REPO/bin" ]] && ! grep -rqE 'TODO|NotImplementedError' "$REPO/bin"
}

# Все *.sh репозитория, кроме каталога .git, через нулевой байт.
sh_files() { find "$REPO" -path "$REPO/.git" -prune -o -type f -name '*.sh' -print0; }

lint_ok() {
    local -a f=()
    command -v shellcheck >/dev/null || return 1
    mapfile -d '' -t f < <(sh_files)
    [[ ${#f[@]} -gt 0 ]] && shellcheck -- "${f[@]}"
}

strict_ok() {
    local -a f=() p=()
    local x
    mapfile -d '' -t f < <(sh_files)
    [[ ${#f[@]} -gt 0 ]] || return 1
    for x in "${f[@]}"; do
        grep -q '^set -euo pipefail' "$x" || return 1
    done
    # Разбор синтаксиса без запуска и без записи .pyc.
    mapfile -d '' -t p < <(find "$REPO" -path "$REPO/.git" -prune -o -type f -name '*.py' -print0)
    for x in "${p[@]}"; do
        python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$x" || return 1
    done
}

count_tests() { { grep -rhE '^[[:space:]]*def test_' "$1" 2>/dev/null || true; } | wc -l; }
tests_ok() {
    local mine base
    mine="$(count_tests "$REPO/tests")"
    base="$(count_tests "$STARTER/tests")"
    [[ "$mine" -gt "$base" ]]
}

secrets_ok() {
    local tracked log
    tracked="$(as_user git -C "$REPO" ls-files -- config.env)" || return 1
    [[ -z "$tracked" ]] || return 1
    log="$(as_user git -C "$REPO" log -p --all)" || return 1
    ! grep -qiE 'BEGIN [A-Z ]*PRIVATE KEY|(password|passwd|token|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]$]{6,}' <<<"$log"
}

timer_ok() {
    [[ "$(systemctl is-enabled "$1" 2>/dev/null)" == enabled && "$(systemctl is-active "$1" 2>/dev/null)" == active ]]
}

# Имя самого нового архива моложе 26 часов (каталог бэкапов доступен только root).
newest_backup() {
    as_root find "$B" -maxdepth 1 -type f -name 'backup-*.tar.gz' -mmin -1560 -printf '%f\n' | LC_ALL=C sort | tail -1
}

backup_ok() {
    local f
    f="$(newest_backup)" || return $?
    [[ -n "$f" ]] || return 1
    as_root tar -tzf "$B/$f" >/dev/null || return 1
    # Сумма из файла .sha256 должна совпасть с суммой архива.
    local expected actual
    expected="$(as_root cat "$B/$f.sha256")" || return 1
    actual="$(as_root sha256sum "$B/$f")" || return 1
    [[ -n "$expected" && "${expected%% *}" == "${actual%% *}" ]]
}

# KEEP из конфига сервера: файл только читается grep, а не подключается через source.
keep_value() {
    local line rc=0
    line="$(as_root grep -E '^KEEP=' /etc/server-automation/config.env)" || rc=$?
    [[ $rc -eq 3 ]] && return 3
    line="${line##*=}"
    line="${line//\"/}"
    if [[ "$line" =~ ^[0-9]+$ ]]; then echo "$line"; else echo 7; fi
}

rotation_ok() {
    local keep n
    keep="$(keep_value)" || return $?
    n="$(as_root find "$B" -maxdepth 1 -type f -name 'backup-*.tar.gz' -printf . | wc -c)" || return $?
    [[ "$n" -ge 1 && "$n" -le "$keep" ]]
}

fresh() {
    local found
    found="$(as_root find "$1" -maxdepth 1 -type f -name "$2" -mmin "-$3" -print)" || return $?
    [[ -n "$found" ]]
}

hardened_ok() {
    local unit
    unit="$(systemctl cat server-automation-backup.service 2>/dev/null)" || return 1
    grep -q '^ProtectSystem=strict' <<<"$unit" && grep -q '^NoNewPrivileges=yes' <<<"$unit"
}

check 0 "репозиторий git: не меньше 5 коммитов, всё закоммичено" git_ok
check 1 "README заполнен: от 4 разделов, есть раздел о восстановлении, не осталось TODO" readme_ok
check 2 "заготовка доделана: в bin/ нет TODO и NotImplementedError" implemented_ok
check 3 "shellcheck не находит замечаний ни в одном *.sh" lint_ok
check 4 "в каждом *.sh есть set -euo pipefail, Python-файлы без синтаксических ошибок" strict_ok
check 5 "в tests/ больше тестов, чем в заготовке" tests_ok
check 6 "config.env не в git, в истории нет ключей и паролей" secrets_ok
check 7 "таймер бэкапа включён и активен" timer_ok server-automation-backup.timer
check 8 "таймер проверок включён и активен" timer_ok server-automation-health.timer
check 9 "свежий бэкап (до 26 ч) читается, контрольная сумма совпадает" backup_ok
check 10 "архивов не больше KEEP из /etc/server-automation/config.env" rotation_ok
check 11 "health.json обновлялся за последние 15 минут" fresh "$STATE" health.json 15
check 12 "есть отчёт за последние 26 часов" fresh "$STATE/reports" 'report-*.md' 1560
check 13 "юнит бэкапа с защитой: ProtectSystem=strict и NoNewPrivileges=yes" hardened_ok

manual "восстановление проверено: архив распакован во временный каталог, diff -r с оригиналом без отличий"
manual "тесты проверяют ошибки: нет источника, плохой KEEP, недоступный адрес"
manual "пути и пороги — только в config.env, в коде нет адресов и /home/ИМЯ"
manual "сообщения коммитов объясняют, что и зачем изменено"
manual "репозиторий опубликован, в README есть пример отчёта"
lab_finish
