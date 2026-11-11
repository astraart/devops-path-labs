#!/usr/bin/env bash
# Проверка практики «Своя лаборатория» (real.start). Только читает состояние машины.
# Запуск: ./labs/real.start/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.start "$@"

ubuntu_2404() { grep -q '^VERSION_ID="24.04"' /etc/os-release; }
devops_in_sudo() { local g; g="$(id -nG devops)"; grep -qw sudo <<<"$g"; }
sudo_rule() {
    local out
    out="$(as_root sudo -l -U devops)" || return $?
    grep -qF '(ALL : ALL) ALL' <<<"$out"
}
marker() { [[ -f /etc/devops-path-lab ]]; }

check 0 "Ubuntu 24.04 LTS" ubuntu_2404
check 1 "пользователь devops в группе sudo" devops_in_sudo
check 2 "devops может выполнять команды через sudo: (ALL : ALL) ALL" sudo_rule
check 3 "файл-метка учебной машины /etc/devops-path-lab" marker
lab_finish
