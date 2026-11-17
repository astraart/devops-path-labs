#!/usr/bin/env bash
# Общие функции для labs/*/break.sh — учебных поломок.
# Поломка меняет систему, поэтому:
#   • работает только на учебной машине — там, где есть файл-метка /etc/devops-path-lab
#     (его создают в практике «Своя лаборатория»);
#   • перед изменениями печатает, что именно сломает и как это вернуть, и ждёт слова yes;
#   • ничего не скачивает и в сеть не ходит.

set -euo pipefail

MARKER=/etc/devops-path-lab
STAMP_DIR=/var/lib/devops-path-lab

# break_init ИД "что изменится" "как вернуть" — проверки и подтверждение. Без yes ничего не меняется.
break_init() {
    local id="$1" what="$2" undo="$3" answer=""
    if [[ ! -f "$MARKER" ]]; then
        echo "Нет файла-метки $MARKER — это не учебная машина. Ничего не изменено." >&2
        echo "Метку создают в практике «Своя лаборатория», только на машине, которую не жалко сломать." >&2
        exit 1
    fi
    if [[ $EUID -ne 0 ]]; then
        echo "Поломке нужны права root: запустите через sudo. Ничего не изменено." >&2
        exit 1
    fi
    echo "Учебная поломка «$id»"
    echo
    echo "Что изменится на этой машине:"
    echo "$what"
    echo
    echo "Как вернуть всё назад (команды есть и в приложении, раздел «Уборка»):"
    echo "$undo"
    echo
    read -r -p "Сломать? Введите yes: " answer || true
    if [[ "$answer" != "yes" ]]; then
        echo "Отменено. Ничего не изменено."
        exit 1
    fi
    echo
}

# break_done ИД — отметка для check.sh, что поломка запускалась: дата в /var/lib/devops-path-lab/ИД.broken.
break_done() {
    mkdir -p "$STAMP_DIR"
    date -Is > "$STAMP_DIR/$1.broken"
    echo
    echo "Готово: машина сломана. Симптом и задание — в приложении, на экране практики."
}
