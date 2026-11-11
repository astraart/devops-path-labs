#!/usr/bin/env bash
# Самопроверка репозитория: shellcheck всех скриптов, векторы кода, запуск каждой проверки.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "shellcheck…"
shellcheck -x lib/common.sh tests/*.sh labs/*/check.sh
echo "векторы кода…"
tests/code-vectors.sh
echo "запуск проверок с числом 1234…"
for f in labs/*/check.sh; do
    out="$("$f" 1234)"
    grep -qE '^Код для приложения: [0-9]{4}-[0-9]{4}$' <<<"$out" || { echo "нет кода: $f"; exit 1; }
done
echo "всё в порядке"
