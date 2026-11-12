#!/usr/bin/env bash
# Резервная копия каталогов из BACKUP_SOURCES в BACKUP_DIR.
#
# Результат: BACKUP_DIR/backup-ГГГГММДД-ЧЧММСС.tar.gz и рядом файл .sha256,
# который проверяется командой `sha256sum -c` из каталога BACKUP_DIR.
# Код выхода: 0 — архив создан и проверен; иначе ошибка, недописанного архива не остаётся.
#
# Настройки приходят из окружения (systemd читает их из EnvironmentFile).
set -euo pipefail

BACKUP_SOURCES="${BACKUP_SOURCES:-/etc}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/server-automation}"

# Проверить, что каждый путь из BACKUP_SOURCES существует.
# Если какого-то нет — сообщение в stderr с этим путём и код 1.
check_sources() {
    # TODO
    echo "TODO: check_sources ($BACKUP_SOURCES)" >&2
    return 1
}

# make_archive ФАЙЛ — создать tar.gz из BACKUP_SOURCES. Пути в архиве — без ведущего «/».
make_archive() {
    # TODO
    echo "TODO: make_archive $1" >&2
    return 1
}

# verify_archive ФАЙЛ — убедиться, что архив читается целиком (tar -tzf).
verify_archive() {
    # TODO
    echo "TODO: verify_archive $1" >&2
    return 1
}

# write_checksum ФАЙЛ — записать ФАЙЛ.sha256 с именем архива без каталога.
write_checksum() {
    # TODO
    echo "TODO: write_checksum $1" >&2
    return 1
}

main() {
    # TODO: в архивах /etc есть /etc/shadow и ключи — файлы должны быть доступны только владельцу.
    # TODO: создайте BACKUP_DIR, если его нет.
    # TODO: при любой ошибке удалите недописанный архив (trap ... ERR или проверка кода).
    local archive
    archive="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    check_sources
    make_archive "$archive"
    verify_archive "$archive"
    write_checksum "$archive"
    echo "$archive"
}

main "$@"
