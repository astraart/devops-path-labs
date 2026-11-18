#!/usr/bin/env bash
# Проверка практики «Репозиторий по описанию без подсказок» (real.git-solo). Только читает репозиторий.
# Запуск: ./labs/real.git-solo/check.sh ЧИСЛО
# Внутри check() set -e не действует, поэтому «пустой вывод» проверяется только после успешной команды (|| return 1).
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.git-solo "$@"

R="$H/git-solo"
g() { as_user git -C "$R" "$@"; }

main3() { local n; n="$(g rev-list --count main)"; [[ "$n" -ge 3 ]]; }
merged() { local out; out="$(g log main --merges --format=%s)"; grep -q 'feature/healthcheck' <<<"$out"; }
tag() { [[ "$(g cat-file -t v1.0.0)" == "tag" ]] && g merge-base --is-ancestor 'v1.0.0^{commit}' main; }
ignored() { g check-ignore -q --no-index app.log && g check-ignore -q --no-index .env; }
no_env() { local out; out="$(g log --all --format=%H -- .env)" || return 1; [[ -z "$out" ]]; }
hook() { local f="$R/.git/hooks/pre-commit"; [[ -x "$f" ]] && grep -Eq 'shellcheck|bash -n' "$f"; }
clean() { local out; out="$(g status --porcelain)" || return 1; [[ -z "$out" ]]; }

check 0 "в ветке main не меньше трёх коммитов" main3
check 1 "ветка feature/healthcheck влита в main коммитом слияния" merged
check 2 "аннотированный тег v1.0.0 на коммите из main" tag
check 3 ".gitignore скрывает app.log и .env" ignored
check 4 ".env нет ни в одном коммите ни одной ветки" no_env
check 5 "хук pre-commit исполняемый и проверяет скрипты (shellcheck или bash -n)" hook
check 6 "рабочий каталог чистый: всё закоммичено" clean
lab_finish
