#!/usr/bin/env bash
# Проверка практики «Object Storage из CLI: Yandex Cloud» (real.cloudops). Только читает состояние машины.
# Запуск: ./labs/real.cloudops/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.cloudops "$@"

profile() { local id; id="$(aws configure get aws_access_key_id --profile yc)"; [[ -n "$id" ]]; }
perms() { [[ "$(stat -c %a "$H/.aws/credentials")" == "600" ]]; }

manual "yaws s3 ls s3://\$B — есть index.html"
manual "versioning бакета — \"Status\": \"Enabled\""
manual "запрос без подписи — 403"
check 3 "профиль yc настроен в AWS CLI" profile
check 4 "файл ~/.aws/credentials доступен только вам (600)" perms
lab_finish
