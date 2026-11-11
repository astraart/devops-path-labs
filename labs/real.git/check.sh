#!/usr/bin/env bash
# Проверка практики «GitHub по SSH и pull request» (real.git). Только читает состояние машины.
# Запуск: ./labs/real.git/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.git "$@"

REPO="${2:-$H/devops-lab}"
merged() {
    local n
    n="$(git -C "$REPO" rev-list --merges --count main)"
    [[ "$n" -ge 1 ]]
}

manual "ssh -T git@github.com — «Hi ВАШ_ЛОГИН! You've successfully authenticated…»"
check 1 "в main репозитория $REPO есть слияние из pull request" merged
lab_finish
