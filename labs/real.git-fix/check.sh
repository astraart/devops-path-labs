#!/usr/bin/env bash
# Проверка практики «Три беды в одном репозитории» (real.git-fix). Только читает репозитории.
# Запуск: ./labs/real.git-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.git-fix "$@"

R="$H/git-fix"
O="$H/git-fix-origin.git"
g() { as_user git -C "$R" "$@"; }
o() { as_user git --git-dir "$O" "$@"; }
bad() { local h; h="$(o log main --format=%H --grep='^Speed up add$')"; [[ -n "$h" ]] && echo "$h"; }

# Ошибка исправлена новым коммитом revert, а не переписыванием истории: в origin есть и плохой коммит, и revert.
reverted() {
    local b msgs
    b="$(bad)" || return 1
    o merge-base --is-ancestor "$b" main || return 1
    msgs="$(o log main --format=%B)"
    grep -q "This reverts commit $b" <<<"$msgs"
}
fixed() { local s; s="$(o show main:calc.sh)"; grep -qF -- "\$1 + \$2" <<<"$s"; }
rescued() { local s; s="$(g log rescue --format=%s)"; grep -qx 'Add payment retries' <<<"$s"; }
no_secret() {
    local out
    g cat-file -e feature/config:config.env.example || return 1
    out="$(g log feature/config --format=%H -- .env)" || return 1
    [[ -z "$out" ]] || return 1
    out="$(o log --all --format=%H -- .env)" || return 1
    [[ -z "$out" ]]
}
ignored() { local s; s="$(g show feature/config:.gitignore)"; grep -qx '\.env' <<<"$s"; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "в origin коммит «Speed up add» отменён через git revert, история не переписана" reverted
check 2 "calc.sh в origin/main снова складывает" fixed
check 3 "потерянный коммит «Add payment retries» спасён в ветку rescue" rescued
check 4 "в ветке feature/config нет .env ни в одном коммите (и в origin его нет)" no_secret
check 5 ".gitignore в feature/config скрывает .env" ignored
lab_finish
