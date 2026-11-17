#!/usr/bin/env bash
# Проверка практики «Argo CD на своём кластере» (real.gitops). Только читает состояние кластера kind через kubectl.
# Запуск: ./labs/real.gitops/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.gitops "$@"

app() { kubectl -n argocd get application web -o jsonpath="$1"; }
synced() { [[ "$(app '{.status.sync.status}')" == "Synced" ]]; }
healthy() { [[ "$(app '{.status.health.status}')" == "Healthy" ]]; }
selfheal() { [[ "$(app '{.spec.syncPolicy.automated.selfHeal}')" == "true" ]]; }
reverted() {
    local want ready
    want="$(kubectl -n web get deploy web -o jsonpath='{.spec.replicas}')"
    ready="$(kubectl -n web get deploy web -o jsonpath='{.status.readyReplicas}')"
    [[ "$want" == "2" && "$ready" == "2" ]]
}

check 0 "приложение web в Argo CD синхронизировано (Synced)" synced
check 1 "приложение web здорово (Healthy)" healthy
check 2 "у приложения включён selfHeal" selfheal
check 3 "после отката в namespace web снова 2 готовые реплики" reverted
manual "git log в gitops-lab: сверху Revert \"web: 3 реплики\", под ним коммит выкатки"
lab_finish
