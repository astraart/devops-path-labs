#!/usr/bin/env bash
# Проверка практики «Эксплуатация кластера: сеть, доступы, обслуживание» (real.kubeops). Только читает состояние машины.
# Запуск: ./labs/real.kubeops/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.kubeops "$@"

nodes() { local out n; out="$(kubectl get nodes --no-headers)"; n="$(awk '$2 == "Ready" && $1 ~ /^ops-/' <<<"$out" | wc -l)"; [[ "$n" -eq 3 ]]; }
prod() {
    local r cms
    r="$(kubectl -n prod get deploy web -o jsonpath='{.status.readyReplicas}')"
    cms="$(kubectl -n prod get configmap -o name)"
    [[ "$r" == "3" ]] && grep -q '^configmap/web-config-' <<<"$cms"
}
netpol() { local out; out="$(kubectl -n shop get networkpolicy -o name)"; [[ -n "$out" ]]; }
rbac() { local out; out="$(kubectl auth can-i get secrets -n staging --as=system:serviceaccount:staging:deployer || true)"; [[ "$out" == "no" ]]; }
pdb() { local n; n="$(kubectl get pdb cart-pdb -o jsonpath='{.status.disruptionsAllowed}')"; [[ "$n" == "1" ]]; }
helm_ok() { local out; out="$(helm status shop -n prod)"; grep -q 'STATUS: deployed' <<<"$out"; }

check 0 "три узла ops-* в состоянии Ready" nodes
check 1 "в prod: web 3/3 и ConfigMap web-config-<хеш>" prod
check 2 "в namespace shop есть NetworkPolicy" netpol
check 3 "deployer из staging не может читать секреты" rbac
check 4 "PDB cart-pdb разрешает одно прерывание" pdb
check 5 "релиз Helm shop в prod — deployed" helm_ok
lab_finish
