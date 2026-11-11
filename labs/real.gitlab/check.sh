#!/usr/bin/env bash
# Проверка практики «GitLab CI: локально и на своём раннере» (real.gitlab). Только читает состояние машины.
# Запуск: ./labs/real.gitlab/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.gitlab "$@"

CI="$H/ci-lab"
artifact() { [[ -s "$CI/.gitlab-ci-local/artifacts/build/dist/app.tar.gz" ]]; }
runner() { as_root grep -q 'executor = "docker"' /etc/gitlab-runner/config.toml; }

manual "gitlab-ci-local: в конце PASS test, PASS build, PASS verify"
check 1 "артефакт build: dist/app.tar.gz" artifact
check 2 "свой раннер с executor = \"docker\" (если делали этот шаг)" runner
manual "Build → Pipelines: пайплайн passed, задачи выполнил ваш раннер"
lab_finish
