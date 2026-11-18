#!/usr/bin/env bash
# Учебная поломка «Три беды в одном репозитории» (real.git-fix).
# Создаёт в домашнем каталоге ученика репозиторий ~/git-fix и его «сервер» ~/git-fix-origin.git
# (обычный голый репозиторий на этой же машине) и устраивает три типичные беды:
#   • на main и уже в origin — коммит с ошибкой, после которого есть и хорошие коммиты;
#   • коммит, сделанный в отсоединённом HEAD: его нет ни в одной ветке;
#   • в неотправленной ветке feature/config закоммичен .env с токеном (токен учебный).
# Система не меняется: только эти два каталога. Запуск: sudo ./labs/real.git-fix/break.sh
# Знаки $ и обратные кавычки в одинарных кавычках ниже — содержимое создаваемых файлов, а не код скрипта.
# shellcheck disable=SC2016
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.git-fix \
"  • создаст репозитории ~/git-fix и ~/git-fix-origin.git в домашнем каталоге ${SUDO_USER:-ученика};
  • другие файлы и настройки git не тронет." \
"  rm -rf ~/git-fix ~/git-fix-origin.git
  sudo rm /var/lib/devops-path-lab/real.git-fix.broken"

if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == root ]]; then
    echo "Запустите через sudo от своего пользователя: репозиторий создаётся в его домашнем каталоге." >&2
    exit 1
fi
home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
if [[ -e "$home/git-fix" || -e "$home/git-fix-origin.git" ]]; then
    echo "Каталог git-fix в домашнем каталоге уже есть — поломка уже запускалась. Уберите её (команды выше) и запустите снова." >&2
    exit 1
fi

# Всё дальше — от имени ученика, с отдельным автором коммитов (его настройки git не нужны).
u() { runuser -u "$SUDO_USER" -- env HOME="$home" "$@"; }
gx() { u git -C "$home/git-fix" -c user.name="DevOps Path Lab" -c user.email="lab@devops-path.invalid" "$@"; }

u git init -q --bare -b main "$home/git-fix-origin.git"
u git clone -q "$home/git-fix-origin.git" "$home/git-fix" 2>/dev/null
gx switch -q -c main

u tee "$home/git-fix/calc.sh" > /dev/null <<'SH'
#!/usr/bin/env bash
# Сумма двух чисел.
set -euo pipefail
echo $(( $1 + $2 ))
SH
u tee "$home/git-fix/test.sh" > /dev/null <<'SH'
#!/usr/bin/env bash
# Тест: ./test.sh печатает ok или FAIL.
set -euo pipefail
got="$(bash "$(dirname "$0")/calc.sh" 2 3)"
if [[ "$got" == 5 ]]; then echo ok; else echo "FAIL: add 2 3 = $got"; exit 1; fi
SH
u chmod +x "$home/git-fix/calc.sh" "$home/git-fix/test.sh"
gx add calc.sh test.sh && gx commit -q -m "Add calc script and test"
printf '# calc\n\nСкладывает два числа: `./calc.sh 2 3`.\n' | u tee "$home/git-fix/README.md" > /dev/null
gx add README.md && gx commit -q -m "Add README"

# Беда 1: ошибка уже в origin, и после неё есть хорошие коммиты.
u sed -i 's/\$1 + \$2/$1 - $2/' "$home/git-fix/calc.sh"
gx commit -q -am "Speed up add"
printf '\nТест: `./test.sh`.\n' | u tee -a "$home/git-fix/README.md" > /dev/null
gx commit -q -am "Document tests"
gx push -q origin main 2>/dev/null

# Беда 2: работа, сделанная в отсоединённом HEAD.
gx switch -q --detach
printf '#!/usr/bin/env bash\n# Повтор платежа до трёх раз.\nset -euo pipefail\nfor i in 1 2 3; do echo "attempt $i"; done\n' | u tee "$home/git-fix/retries.sh" > /dev/null
gx add retries.sh && gx commit -q -m "Add payment retries"
gx switch -q main 2>/dev/null

# Беда 3: токен в неотправленной ветке.
gx switch -q -c feature/config
printf 'API_URL=https://api.example.com\n' | u tee "$home/git-fix/config.env.example" > /dev/null
printf 'API_TOKEN=lab-fake-token-0000\n' | u tee "$home/git-fix/.env" > /dev/null
gx add config.env.example .env && gx commit -q -m "Add config"
gx switch -q main

break_done real.git-fix
echo "Начните с: cd ~/git-fix && ./test.sh && git log --oneline --all --graph"
