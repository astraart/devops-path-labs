#!/usr/bin/env bash
# Проверка практики «Плейбук для своих серверов» (real.ansible). Только читает состояние машины.
# Запуск: ./labs/real.ansible/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.ansible "$@"

A="$H/ansible-lab"
syntax() { ansible-playbook -i "$A/inventory.ini" "$A/site.yml" --syntax-check; }
lint() { command -v ansible-lint >/dev/null && ansible-lint "$A/site.yml"; }

manual "ansible -i inventory.ini web -m ping — SUCCESS и \"ping\": \"pong\""
manual "второй запуск ansible-playbook — changed=0"
manual "curl -s http://IP_ВМ — <h1>Managed by Ansible</h1>"
check 3 "site.yml проходит --syntax-check" syntax
check 4 "ansible-lint без замечаний" lint
lab_finish
