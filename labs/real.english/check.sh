#!/usr/bin/env bash
# Проверка практики «Английский в терминале и документации» (real.english). Только читает файлы в ~/english.
# Запуск: ./labs/real.english/check.sh ЧИСЛО
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.english "$@"

DIR="$H/english"
enoent() { grep -q 'No such file or directory' "$DIR/errors.txt"; }
eacces() { grep -q 'Permission denied' "$DIR/errors.txt"; }
answer() { grep -iE "^$1:" "$DIR/answers.txt" | head -n 1 | cut -d: -f2- | tr -d '[:space:]'; }
answers() {
    [[ "$(answer ls-human)" == "-h" ]] || return 1
    case "$(answer tar-list)" in -t | --list) ;; *) return 1 ;; esac
    [[ "$(answer crontab-boot)" == "@reboot" ]] || return 1
    [[ "$(answer ssh-port)" == "-p" ]] || return 1
    case "$(answer grep-ignore-case)" in -i | --ignore-case) ;; *) return 1 ;; esac
}
commits() {
    local subjects n
    subjects="$(as_user git -C "$DIR/notes" log --format=%s)"
    n="$(wc -l <<<"$subjects")"
    [[ "$n" -ge 3 ]] || return 1
    ! grep -qE '^(Added|Fixed|Updated|Changed|Removed|Deleted|Created)\b|\.$' <<<"$subjects"
}

check 0 "в errors.txt есть «No such file or directory»" enoent
check 1 "в errors.txt есть «Permission denied»" eacces
check 2 "все пять ответов из документации верны" answers
check 3 "3 коммита или больше в повелительном наклонении, без точки в конце" commits
manual "ссылка на issue с вашей ошибкой сохранена"
lab_finish
