#!/usr/bin/env bash
# Проверка практики «Terraform без счёта за облако» (real.terraform). Только читает состояние машины.
# Запуск: ./labs/real.terraform/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.terraform "$@"

TF="$H/tf-lab"
page() { local out; out="$(curl -fsS -m 3 http://localhost:8080/)"; grep -q '<title>Welcome to nginx!</title>' <<<"$out"; }
state() { local out; out="$(terraform -chdir="$TF" state list)"; grep -qx 'docker_container.web' <<<"$out" && grep -qx 'docker_image.nginx' <<<"$out"; }
# plan без блокировки и без записи плана: только сравнение
no_changes() { terraform -chdir="$TF" plan -detailed-exitcode -lock=false -input=false; }

check 0 "localhost:8080 отдаёт страницу nginx" page
check 1 "в state: docker_container.web и docker_image.nginx" state
check 2 "terraform plan: изменений нет" no_changes
lab_finish
