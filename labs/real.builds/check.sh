#!/usr/bin/env bash
# Проверка практики «Артефакт из исходников: notes-api» (real.builds). Только читает состояние машины:
# собранный бинарник не запускается — проверяются сам файл, его метаданные и контрольная сумма.
# Запуск: ./labs/real.builds/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.builds "$@"

ART="$H/artifacts"
BIN="$ART/notes-api"
built() { [[ -f "$BIN" && -x "$BIN" ]]; }
static() { file -b "$BIN" | grep -q 'statically linked'; }
buildinfo() {
    local out
    out="$(go version -m "$BIN")"
    grep -q 'CGO_ENABLED=0' <<<"$out" && grep -q -- '-trimpath=true' <<<"$out"
}
sums() { (cd "$ART" && sha256sum --status -c SHA256SUMS); }

check 0 "artifacts/notes-api в домашнем каталоге собран и исполняемый" built
check 1 "бинарник статический (file: statically linked)" static
check 2 "собран с CGO_ENABLED=0 и -trimpath (go version -m)" buildinfo
check 3 "artifacts/SHA256SUMS совпадает с бинарником" sums
manual "curl -s localhost:8080/version при запущенном бинарнике показывает \"version\":\"1.0.0\""
lab_finish
