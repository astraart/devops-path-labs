#!/usr/bin/env bash
# Ротация: в BACKUP_DIR остаются KEEP самых новых архивов backup-*.tar.gz,
# более старые удаляются вместе с их файлами .sha256. Другие файлы не трогаются.
#
# Код выхода: 0 — готово; 2 — KEEP не целое положительное число (ничего не удалено).
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/server-automation}"
KEEP="${KEEP:-7}"

main() {
    # TODO: проверьте KEEP: только цифры и больше нуля, иначе сообщение в stderr и exit 2.
    # TODO: соберите список архивов в массив. Имена содержат дату, поэтому порядок по имени
    #       совпадает с порядком по времени — сортируйте с LC_ALL=C, а не разбирайте вывод ls.
    # TODO: удалите все, кроме KEEP последних, и их .sha256. Печатайте, что удалено.
    echo "TODO: rotate.sh (BACKUP_DIR=$BACKUP_DIR KEEP=$KEEP)" >&2
    return 1
}

main "$@"
