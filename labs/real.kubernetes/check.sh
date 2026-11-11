#!/usr/bin/env bash
# Проверка практики «Свой кластер kind и деплой» (real.kubernetes). Только читает состояние машины.
# Запуск: ./labs/real.kubernetes/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.kubernetes "$@"

client() { local v; v="$(kubectl version --client)"; grep -q 'Client Version: v1\.37\.' <<<"$v"; }
node() { local out; out="$(kubectl get nodes --no-headers)"; awk '$1 == "lab-control-plane" && $2 == "Ready" { ok = 1 } END { exit !ok }' <<<"$out"; }
deploy() { local r; r="$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')"; [[ "$r" == "4" ]]; }

check 0 "kubectl версии v1.37" client
check 1 "узел lab-control-plane — Ready" node
check 2 "deployment web: готово 4 из 4" deploy
lab_finish
