#!/usr/bin/env bash
# Проверка практики «Портфолио, резюме и пробное собеседование» (real.career). Только читает состояние машины.
# Запуск: ./labs/real.career/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.career "$@"

REPO="${2:-$H/shop-api}"
clean() {
    local hits
    hits="$(git -C "$REPO" log --all -p | grep -cE 'AKIA[0-9A-Z]{16}|PASSWORD=' || true)"
    [[ "$hits" == "0" ]]
}
readme() { [[ -s "$REPO/README.md" ]]; }

manual "ссылка на репозиторий открывается без входа, пайплайн зелёный"
manual "запись пробного интервью: на каждый вопрос — ответ по существу"
manual "траблшутинг: причина найдена снаружи внутрь, исправление проверено"
check 3 "в истории $REPO нет ключей AWS и PASSWORD=" clean
check 4 "в $REPO есть README.md" readme
lab_finish
