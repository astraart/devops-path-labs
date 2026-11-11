#!/usr/bin/env bash
# Проверка практики «Укрепление своей ВМ» (real.secops). Только читает состояние машины.
# Запуск: ./labs/real.secops/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.secops "$@"

sshd_conf() {
    local out
    out="$(as_root sshd -T)" || return $?
    grep -qx 'passwordauthentication no' <<<"$out" && grep -qx 'permitrootlogin no' <<<"$out"
}
# вход по паролю на localhost должен отклоняться; known_hosts не трогаем
no_password() {
    local out
    out="$(ssh -o BatchMode=yes -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 localhost true 2>&1 || true)"
    grep -q 'Permission denied (publickey' <<<"$out"
}
f2b() { local out; out="$(as_root fail2ban-client status sshd)" || return $?; grep -q 'Status for the jail: sshd' <<<"$out"; }

check 0 "sshd: PasswordAuthentication no и PermitRootLogin no" sshd_conf
check 1 "вход без ключа отклоняется: Permission denied (publickey)" no_password
check 2 "fail2ban охраняет sshd" f2b
lab_finish
