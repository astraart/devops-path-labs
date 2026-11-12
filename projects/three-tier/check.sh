#!/usr/bin/env bash
# Проверка проекта 3 «Инфраструктура из трёх машин» (project.three-tier). Только читает:
# репозиторий ученика (git, Terraform, Ansible), список машин LXD (lxc list), выходные значения
# Terraform (terraform output) и ответы стенда. Сетевые запросы — только к машинам LXD на этом
# компьютере (мост lxdbr0), наружу скрипт не ходит.
# Запуск: ./projects/three-tier/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]   (по умолчанию ~/three-tier)
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init project.three-tier "$@"

REPO="${2:-$H/three-tier}"
echo "Репозиторий: $REPO"
echo

git_ok() {
    local n dirty
    n="$(as_user git -C "$REPO" rev-list --count HEAD)" || return 1
    dirty="$(as_user git --no-optional-locks -C "$REPO" status --porcelain)" || return 1
    [[ "$n" -ge 5 && -z "$dirty" ]]
}

readme_ok() {
    local f="$REPO/README.md" sections
    [[ -f "$f" ]] || return 1
    sections="$(grep -c '^## ' "$f")" || return 1
    [[ "$sections" -ge 4 ]] && grep -q 'terraform apply' "$f" && grep -q 'ansible-playbook' "$f" && ! grep -q 'TODO' "$f"
}

# В git нет состояния Terraform, его кеша, инвентаря и пароля от vault; файл блокировок провайдеров — есть.
state_ok() {
    local files
    files="$(as_user git -C "$REPO" ls-files)" || return 1
    ! grep -qE '(^|/)(terraform\.tfstate|[^/]*\.tfstate\.[^/]*|\.terraform/|\.vault_pass$|inventory\.ini$)' <<<"$files" \
        && grep -qx 'terraform/.terraform.lock.hcl' <<<"$files"
}

# Версии провайдеров закреплены, в Terraform не осталось TODO.
versions_ok() {
    local d="$REPO/terraform"
    [[ -f "$d/versions.tf" ]] || return 1
    python3 -I - "$d/versions.tf" <<'PY' || return 1
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
bodies = re.findall(r'\w+\s*=\s*\{([^{}]*source\s*=\s*"[^"]+"[^{}]*)\}', text)
sys.exit(0 if len(bodies) >= 2 and all(re.search(r'version\s*=\s*"[^"]+"', b) for b in bodies) else 1)
PY
    ! grep -rq 'TODO' "$d"
}

roles_ok() {
    local r
    for r in common postgres app lb; do
        grep -q -- '- name:' "$REPO/ansible/roles/$r/tasks/main.yml" 2>/dev/null || return 1
    done
    ! grep -rq 'TODO' "$REPO/ansible"
}

# Пароль базы — только в зашифрованном vault.yml.
vault_ok() {
    local v="$REPO/ansible/group_vars/all/vault.yml"
    local first=""
    [[ -f "$v" ]] || return 1
    read -r first <"$v" || true
    [[ "$first" == "\$ANSIBLE_VAULT;"* ]] || return 1
    ! grep -rIE --exclude=vault.yml --exclude='*.example' 'password:[[:space:]]*["'\'']?[^"'\''{[:space:]]' "$REPO/ansible"
}

# lxc без sudo, если ученик в группе lxd; иначе через sudo без пароля, иначе «?».
lx() {
    if lxc list --format csv -c n >/dev/null 2>&1; then
        lxc "$@"
    else
        as_root lxc "$@"
    fi
}

# «имя адрес» для работающих машин tt-*.
machines() {
    command -v lxc >/dev/null || return 1
    local out
    out="$(lx list --format csv -c ns4)" || return $?
    awk -F, '$1 ~ /^tt-/ && $2 == "RUNNING" { split($3, a, " "); print $1, a[1] }' <<<"$out"
}

ip_of() {
    local m
    m="$(machines)" || return $?
    awk -v n="$1" '$1 == n { print $2 }' <<<"$m"
}

running_ok() {
    local m
    m="$(machines)" || return $?
    grep -q '^tt-lb ' <<<"$m" && grep -q '^tt-db ' <<<"$m" && grep -q '^tt-app[0-9]* ' <<<"$m"
}

# Машинами управляет Terraform: адрес балансировщика в его выходных значениях совпадает с LXD.
terraform_ok() {
    local lb tf
    command -v terraform >/dev/null || return 1
    lb="$(ip_of tt-lb)" || return $?
    tf="$(as_user terraform -chdir="$REPO/terraform" output -raw lb_ip)" || return 1
    [[ -n "$lb" && "$tf" == "$lb" ]]
}

http_ok() {
    local lb
    lb="$(ip_of tt-lb)" || return $?
    [[ -n "$lb" ]] && curl -fsS --max-time 5 "http://$lb$1" >/dev/null
}

notes_ok() {
    local lb body
    lb="$(ip_of tt-lb)" || return $?
    body="$(curl -fsS --max-time 5 "http://$lb/notes")" || return 1
    [[ "$body" == \[* ]]
}

# Порт закрыт для этой машины (подключение не устанавливается за 3 секунды).
closed() {
    local ip
    ip="$(ip_of "$1")" || return $?
    [[ -n "$ip" ]] || return 1
    ! timeout 3 bash -c "exec 3<>/dev/tcp/$ip/$2" 2>/dev/null
}

apps_closed() {
    local m name ok=0
    m="$(machines)" || return $?
    while read -r name _; do
        [[ "$name" == tt-app* ]] || continue
        ok=1
        closed "$name" 8080 || return 1
    done <<<"$m"
    [[ $ok -eq 1 ]]
}

# SSH (22) отвечает на каждой машине tt-*.
ssh_open() {
    local m name ip ok=0
    m="$(machines)" || return $?
    while read -r name ip; do
        [[ -n "$name" ]] || continue
        ok=1
        timeout 3 bash -c "exec 3<>/dev/tcp/$ip/22" 2>/dev/null || return 1
    done <<<"$m"
    [[ $ok -eq 1 ]]
}

check 0 "репозиторий git: не меньше 5 коммитов, всё закоммичено" git_ok
check 1 "README: от 4 разделов, команды terraform apply и ansible-playbook, не осталось TODO" readme_ok
check 2 "в git нет состояния Terraform, инвентаря и пароля vault; .terraform.lock.hcl есть" state_ok
check 3 "версии провайдеров Terraform закреплены, в terraform/ нет TODO" versions_ok
check 4 "роли common, postgres, app и lb написаны, в ansible/ нет TODO" roles_ok
check 5 "пароль базы только в зашифрованном vault.yml" vault_ok
check 6 "машины tt-lb, tt-db и tt-app работают" running_ok
check 7 "машинами управляет Terraform: lb_ip совпадает с адресом tt-lb" terraform_ok
check 8 "балансировщик отвечает на /healthz" http_ok /healthz
check 9 "через балансировщик /readyz — приложение видит базу" http_ok /readyz
check 10 "через балансировщик /notes отдаёт список заметок" notes_ok
check 11 "порт базы 5432 закрыт для этой машины" closed tt-db 5432
check 12 "порт приложения 8080 закрыт для этой машины" apps_closed
check 13 "SSH открыт на всех машинах: межсетевой экран не отрезал Ansible" ssh_open

manual "terraform destroy, затем apply и ansible-playbook поднимают всё с нуля; время записано в README"
manual "повторный ansible-playbook: changed=0 на всех машинах"
manual "app_count = 2: при остановке одного приложения балансировщик отвечает"
manual "пароль от vault не в git, его знает только владелец"
manual "README: схема, как поднять и удалить стенд, что делать при недоступной базе"
lab_finish
