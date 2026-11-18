#!/usr/bin/env bash
# Учебная поломка «Пайплайн красный, а на main не запускается вовсе» (real.cicd-fix).
# Создаёт в домашнем каталоге ученика репозиторий ~/ci-fix: Makefile, скрипты и workflow GitHub Actions —
# с четырьмя ошибками, из-за которых make ci падает локально, а workflow не срабатывает на push в main.
# Система не меняется: только этот каталог. Запуск: sudo ./labs/real.cicd-fix/break.sh
# Знаки $ в одинарных кавычках ниже — содержимое создаваемых файлов, а не код скрипта.
# shellcheck disable=SC2016
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.cicd-fix \
"  • создаст репозиторий ~/ci-fix в домашнем каталоге ${SUDO_USER:-ученика};
  • другие файлы и настройки git не тронет." \
"  rm -rf ~/ci-fix
  sudo rm /var/lib/devops-path-lab/real.cicd-fix.broken"

if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == root ]]; then
    echo "Запустите через sudo от своего пользователя: репозиторий создаётся в его домашнем каталоге." >&2
    exit 1
fi
home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
if [[ -e "$home/ci-fix" ]]; then
    echo "Каталог ci-fix в домашнем каталоге уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi

u() { runuser -u "$SUDO_USER" -- env HOME="$home" "$@"; }
gx() { u git -C "$home/ci-fix" -c user.name="DevOps Path Lab" -c user.email="lab@devops-path.invalid" "$@"; }
R="$home/ci-fix"

u mkdir -p "$R/scripts" "$R/.github/workflows"
u git init -q -b main "$R"

u tee "$R/scripts/greet.sh" > /dev/null <<'SH'
#!/usr/bin/env bash
# Приветствие: ./scripts/greet.sh ИМЯ
set -euo pipefail
name=${1:-world}
echo Hello, $name
SH
u tee "$R/scripts/test.sh" > /dev/null <<'SH'
#!/usr/bin/env bash
# Тест greet.sh: печатает ok или FAIL.
set -euo pipefail
got="$(bash "$(dirname "$0")/greet.sh" DevOps)"
if [[ "$got" == "Hello, DevOps" ]]; then echo ok; else echo "FAIL: $got"; exit 1; fi
SH
u chmod 755 "$R/scripts/greet.sh"
# Ошибка 1: тест не исполняемый, а Makefile запускает его как ./scripts/test.sh.
u chmod 644 "$R/scripts/test.sh"

# Ошибка 2: в рецепте цели test — пробелы вместо табуляции.
printf '.PHONY: ci lint test\n\nci: lint test\n\nlint:\n\tshellcheck scripts/*.sh\n\ntest:\n    ./scripts/test.sh\n' | u tee "$R/Makefile" > /dev/null

# Ошибка 3 — в greet.sh: $name без кавычек (shellcheck SC2086).
# Ошибка 4: workflow ждёт push в master, а ветка репозитория — main.
u tee "$R/.github/workflows/ci.yml" > /dev/null <<'YAML'
name: CI
on:
  push:
    branches: [master]
  pull_request:
permissions:
  contents: read
jobs:
  ci:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - run: make ci
YAML

gx add -A
gx commit -q -m "Add greet script, tests and CI"

break_done real.cicd-fix
echo "Начните с: cd ~/ci-fix && make ci"
