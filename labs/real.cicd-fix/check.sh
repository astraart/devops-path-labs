#!/usr/bin/env bash
# Проверка практики «Пайплайн красный» (real.cicd-fix). Только читает репозиторий:
# make -n (пробный прогон), git ls-files, shellcheck и текст workflow.
# Запуск: ./labs/real.cicd-fix/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.cicd-fix "$@"

R="$H/ci-fix"
W="$R/.github/workflows/ci.yml"
g() { as_user git -C "$R" "$@"; }
on_section() { awk '/^"?on"?:/ { f = 1; next } /^[^[:space:]#]/ { f = 0 } f' "$W"; }

make_parses() { as_user make -s -n -C "$R" ci >/dev/null; }
exec_bit() { local s; s="$(g ls-files -s scripts/test.sh)" || return 1; [[ "$s" == 100755* ]]; }
lint() { command -v shellcheck >/dev/null || return 1; (cd "$R" && shellcheck scripts/*.sh); }
on_main() { local s; s="$(on_section)" || return 1; grep -Eq '(\[|[[:space:]-])main(\]|,|[[:space:]]|$)' <<<"$s" && ! grep -q 'master' <<<"$s"; }
committed() { local out n; out="$(g status --porcelain)" || return 1; n="$(g rev-list --count HEAD)" || return 1; [[ -z "$out" && "$n" -ge 2 ]]; }

check 0 "поломка запускалась на этой машине (break.sh)" was_broken
check 1 "make -n ci: Makefile читается (рецепты — через табуляцию)" make_parses
check 2 "scripts/test.sh исполняемый в git (режим 100755)" exec_bit
check 3 "shellcheck scripts/*.sh без замечаний" lint
check 4 "workflow запускается на push в main" on_main
check 5 "исправления закоммичены, рабочий каталог чистый" committed
lab_finish
