#!/usr/bin/env bash
# Проверка практики «Свой CA, HTTPS и контроль сроков» (real.secops2). Только читает состояние машины.
# Запуск: ./labs/real.secops2/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.secops2 "$@"

P="$H/pki"
verify() { openssl verify -CAfile "$P/ca.crt" -verify_hostname lab.local "$P/server.crt"; }
untrusted() { local rc=0; curl -s -o /dev/null -m 3 --resolve lab.local:443:127.0.0.1 https://lab.local/ || rc=$?; [[ $rc -eq 60 ]]; }
trusted() { local code; code="$(curl -s -o /dev/null -w '%{http_code}' -m 3 --resolve lab.local:443:127.0.0.1 --cacert "$P/ca.crt" https://lab.local/)"; [[ "$code" == "200" ]]; }

check 0 "сертификат server.crt подписан вашим CA и выдан на lab.local" verify
check 1 "без --cacert curl отказывает (код 60)" untrusted
check 2 "с --cacert ~/pki/ca.crt — ответ 200" trusted
lab_finish
