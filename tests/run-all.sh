#!/usr/bin/env bash
# Самопроверка репозитория: shellcheck всех скриптов, векторы кода, запуск каждой проверки,
# синтаксис Python в заготовках проектов.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "shellcheck…"
shellcheck -x lib/common.sh lib/breaking.sh tests/*.sh labs/*/check.sh labs/*/break.sh projects/*/check.sh projects/*/starter/*.sh projects/*/starter/bin/*.sh
echo "векторы кода…"
tests/code-vectors.sh
echo "поломки: первая команда — break_init (метка, root, подтверждение)…"
for f in labs/*/break.sh; do
    first="$(grep -vE '^\s*(#|$|set -euo pipefail|source )' "$f" | awk 'NR == 1')"
    [[ "$first" == break_init* ]] || { echo "до break_init что-то выполняется: $f"; exit 1; }
    grep -q '^break_done ' "$f" || { echo "нет break_done: $f"; exit 1; }
    [[ -x "${f%break.sh}check.sh" ]] || { echo "у поломки нет check.sh: $f"; exit 1; }
done
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
