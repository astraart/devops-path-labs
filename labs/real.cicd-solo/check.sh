#!/usr/bin/env bash
# Проверка практики «Пайплайн по требованиям без подсказок» (real.cicd-solo). Только читает репозиторий:
# make -n (пробный прогон, команды не выполняются), shellcheck и разбор текста workflow.
# Запуск: ./labs/real.cicd-solo/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.cicd-solo "$@"

R="$H/ci-solo"
W="$R/.github/workflows/ci.yml"
# Раздел on: workflow — до следующего ключа верхнего уровня.
on_section() { awk '/^"?on"?:/ { f = 1; next } /^[^[:space:]#]/ { f = 0 } f' "$W"; }

make_ok() {
    as_user make -s -n -C "$R" ci >/dev/null || return 1
    grep -Eq '^ci:.*\blint\b' "$R/Makefile" && grep -Eq '^ci:.*\btest\b' "$R/Makefile" || return 1
    grep -Eq '^\.PHONY:.*\bci\b' "$R/Makefile" && grep -Eq '^\.PHONY:.*\blint\b' "$R/Makefile" && grep -Eq '^\.PHONY:.*\btest\b' "$R/Makefile"
}
scripts_ok() {
    local f
    command -v shellcheck >/dev/null || return 1
    mapfile -t f < <(as_user git -C "$R" ls-files '*.sh')
    [[ ${#f[@]} -gt 0 ]] && (cd "$R" && shellcheck -- "${f[@]}")
}
no_tabs() { [[ -f "$W" ]] && ! grep -q $'\t' "$W"; }
triggers() { local s; s="$(on_section)" || return 1; grep -q 'pull_request' <<<"$s" && grep -Eq '(\[|[[:space:]-])main(\]|,|[[:space:]]|$)' <<<"$s"; }
perms() {
    local block
    grep -Eq '^permissions:[[:space:]]*(read-all|\{[[:space:]]*contents:[[:space:]]*read[[:space:]]*\})[[:space:]]*$' "$W" && return 0
    block="$(awk '/^permissions:[[:space:]]*$/ { f = 1; next } /^[^[:space:]#]/ { f = 0 } f' "$W")" || return 1
    grep -Eq '^[[:space:]]+contents:[[:space:]]*read[[:space:]]*$' <<<"$block" && ! grep -q 'write' <<<"$block"
}
# Все сторонние действия закреплены по полному хешу коммита, а не по тегу.
pinned() {
    local uses
    uses="$(grep -E '^[[:space:]-]*uses:' "$W")" || return 1
    ! grep -Ev 'uses:[[:space:]]*[^@[:space:]]+@[0-9a-f]{40}([[:space:]]|$)' <<<"$uses"
}
job() { grep -Eq '^[[:space:]]+timeout-minutes:[[:space:]]*[0-9]+' "$W" && grep -Eq 'run:.*make ci' "$W"; }
concurrency() { grep -Eq '^concurrency:' "$W" && grep -Eq '^[[:space:]]+cancel-in-progress:[[:space:]]*true' "$W"; }
committed() { local out; out="$(as_user git -C "$R" status --porcelain)" || return 1; [[ -z "$out" ]] && as_user git -C "$R" ls-files --error-unmatch .github/workflows/ci.yml Makefile >/dev/null; }

check 0 "Makefile: цели lint, test и ci (ci вызывает обе), все в .PHONY; make -n ci без ошибок" make_ok
check 1 "скрипты *.sh в репозитории проходят shellcheck" scripts_ok
check 2 "workflow без табуляций (YAML их не допускает)" no_tabs
check 3 "workflow запускается на push в main и на pull_request" triggers
check 4 "permissions: contents: read — токену только чтение" perms
check 5 "все действия uses: закреплены по 40-символьному хешу" pinned
check 6 "у задачи есть timeout-minutes, и она запускает make ci" job
check 7 "concurrency с cancel-in-progress: true — старые запуски ветки отменяются" concurrency
check 8 "Makefile и workflow закоммичены, рабочий каталог чистый" committed
lab_finish
