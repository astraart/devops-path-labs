#!/usr/bin/env bash
# Проверка практики «ВМ в облаке и контроль расходов» (real.cloud). Только читает состояние машины.
# Запуск: ./labs/real.cloud/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.cloud "$@"

key() { [[ -f "$H/.ssh/id_ed25519" ]] && [[ "$(stat -c %a "$H/.ssh/id_ed25519")" == "600" ]]; }

manual "консоль биллинга: бюджет создан, оповещение настроено"
manual "ssh ubuntu@ПУБЛИЧНЫЙ_IP true — вход только по ключу"
manual "после удаления: нет ВМ, дисков и зарезервированных IP"
check 3 "SSH-ключ ~/.ssh/id_ed25519 есть и доступен только вам (600)" key
lab_finish
