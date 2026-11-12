#!/usr/bin/env bash
# Самопроверка репозитория: shellcheck всех скриптов, векторы кода, запуск каждой проверки,
# синтаксис Python в заготовках проектов.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "shellcheck…"
shellcheck -x lib/common.sh tests/*.sh labs/*/check.sh projects/*/check.sh projects/*/starter/*.sh projects/*/starter/bin/*.sh
echo "векторы кода…"
tests/code-vectors.sh
echo "синтаксис Python в заготовках…"
for f in projects/*/starter/bin/*.py projects/*/starter/tests/*.py; do
    python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$f"
done
echo "запуск проверок с числом 1234…"
for f in labs/*/check.sh projects/*/check.sh; do
    out="$("$f" 1234)"
    grep -qE '^Код для приложения: [0-9]{4}-[0-9]{4}$' <<<"$out" || { echo "нет кода: $f"; exit 1; }
done
echo "всё в порядке"
