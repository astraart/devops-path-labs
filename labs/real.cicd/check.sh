#!/usr/bin/env bash
# Проверка практики «Пайплайн GitHub Actions» (real.cicd). Только читает состояние машины.
# Запуск: ./labs/real.cicd/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.cicd "$@"

REPO="${2:-$H/devops-lab}"
workflow() { [[ -f "$REPO/.github/workflows/ci.yml" ]] && grep -q 'pull_request' "$REPO/.github/workflows/ci.yml"; }

manual "вкладка Actions: последний запуск на main — зелёный"
manual "PR с ошибкой: проверка красная, merge заблокирован"
check 2 "в $REPO есть .github/workflows/ci.yml с запуском на pull_request" workflow
lab_finish
