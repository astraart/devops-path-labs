#!/usr/bin/env bash
# Проверка практики «Итоговый проект на настоящих инструментах» (real.capstone). Только читает состояние машины.
# Запуск: ./labs/real.capstone/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.capstone "$@"

helm_ok() { local out; out="$(helm status shop-api -n prod)"; grep -q 'STATUS: deployed' <<<"$out"; }

manual "Pipelines в GitLab: main зелёный, deploy-prod ждёт ручного запуска"
check 1 "релиз Helm shop-api в prod — deployed" helm_ok
manual "curl через port-forward с --cacert — {\"status\":\"ok\"}"
manual "README: новый человек поднимает проект без вопросов"
lab_finish
