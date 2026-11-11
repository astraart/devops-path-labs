#!/usr/bin/env bash
# Общие функции для labs/*/check.sh.
# Скрипты проверки только ЧИТАЮТ состояние машины: ничего не создают, не меняют и не удаляют,
# в сеть не ходят (кроме запросов к localhost), sudo используют только там, где без него не прочитать.

set -euo pipefail

LAB_ID=""
CHALLENGE=""
MASK=0
CHECKED=0
NEED_ROOT=0
MANUAL=()

# Домашний каталог ученика, даже если скрипт запущен через sudo.
LAB_USER="${SUDO_USER:-${USER:-$(id -un)}}"
H="$(getent passwd "$LAB_USER" | cut -d: -f6)"
H="${H:-$HOME}"

# lab_init ИД ЧИСЛО — начало проверки. ЧИСЛО — четыре цифры с экрана практики в приложении.
lab_init() {
    LAB_ID="$1"
    CHALLENGE="${2:-}"
    if [[ ! "$CHALLENGE" =~ ^[0-9]{4}$ ]]; then
        echo "Использование: $0 ЧИСЛО [ПУТЬ]" >&2
        echo "ЧИСЛО — четыре цифры с экрана практики в приложении DevOps Path." >&2
        exit 2
    fi
    echo "Проверка практики «$LAB_ID»"
    echo
}

# as_root КОМАНДА — выполнить от root: напрямую, если уже root, иначе через sudo без пароля.
# Код 3 — прав нет (проверка помечается «?», а не «нет»).
as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif sudo -n true 2>/dev/null; then
        sudo -n "$@"
    else
        return 3
    fi
}

# check НОМЕР "что проверяем" ФУНКЦИЯ [АРГУМЕНТЫ] — номер совпадает с номером проверки в приложении.
check() {
    local n="$1" desc="$2" rc=0
    shift 2
    CHECKED=$((CHECKED + 1))
    ( "$@" ) >/dev/null 2>&1 || rc=$?
    if [[ $rc -eq 0 ]]; then
        MASK=$((MASK | (1 << n)))
        echo "  ✓ $desc"
    elif [[ $rc -eq 3 ]]; then
        NEED_ROOT=1
        echo "  ? $desc — нужны права root: запустите через sudo"
    else
        echo "  ✗ $desc"
    fi
}

# manual "что проверить самостоятельно" — пункт, который скрипт проверить не может (облако, веб-интерфейс).
manual() {
    MANUAL+=("$1")
}

# Код для приложения: 24 бита = маска пройденных проверок (16 бит) и 8 бит контроля,
# перемешанные с SHA-256 от «devops-path:ИД:ЧИСЛО». Это обратная связь, а не защита от обмана.
lab_code() {
    local lab="$1" challenge="$2" mask="$3" hex key value code
    hex="$(printf '%s' "devops-path:${lab}:${challenge}" | sha256sum | cut -c1-8)"
    key=$((16#$hex))
    value=$(((mask << 8) | (key & 0xFF)))
    code=$((value ^ ((key >> 8) & 0xFFFFFF)))
    printf '%04d-%04d\n' $((code / 10000)) $((code % 10000))
}

lab_finish() {
    if [[ ${#MANUAL[@]} -gt 0 ]]; then
        echo
        echo "Проверьте сами и отметьте в приложении:"
        local m
        for m in "${MANUAL[@]}"; do echo "  • $m"; done
    fi
    if [[ $NEED_ROOT -eq 1 ]]; then
        echo
        echo "Часть проверок требует root. Повторите: sudo $0 $CHALLENGE"
    fi
    echo
    echo "Код для приложения: $(lab_code "$LAB_ID" "$CHALLENGE" "$MASK")"
}
