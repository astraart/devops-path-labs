#!/usr/bin/env bash
# Учебная поломка «Отчёт не находит данные» (real.linux-files-fix).
# Создаёт в /opt/lab-files маленькое «приложение»: скрипт отчёта, конфиг и 12 CSV-файлов, — и ломает его
# тремя способами, которые встречаются в жизни: конфиг с концами строк Windows (CRLF), повторённый ключ
# в конфиге и каталог с данными, который кто-то перенёс в архив. Только файлы в /opt/lab-files.
# Запуск: sudo ./labs/real.linux-files-fix/break.sh
set -euo pipefail
# shellcheck source=../../lib/breaking.sh
source "$(dirname "$0")/../../lib/breaking.sh"

break_init real.linux-files-fix \
"  • создаст каталог /opt/lab-files: bin/report.sh, conf/app.conf и 12 файлов *.csv;
  • сломает конфиг и перенесёт данные внутри /opt/lab-files — другие каталоги не тронет." \
"  sudo rm -r /opt/lab-files /var/lib/devops-path-lab/real.linux-files-fix.broken"

if [[ -e /opt/lab-files ]]; then
    echo "Каталог /opt/lab-files уже есть — поломка уже запускалась. Уберите его (команда выше) и запустите снова." >&2
    exit 1
fi

mkdir -p /opt/lab-files/bin /opt/lab-files/conf /opt/lab-files/data

# Скрипт отчёта: берёт DATA_DIR из конфига и считает CSV-файлы в этом каталоге.
cat > /opt/lab-files/bin/report.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
conf=/opt/lab-files/conf/app.conf
data_dir="$(grep '^DATA_DIR=' "$conf" | tail -n 1 | cut -d= -f2-)"
cd "$data_dir"
count="$(find . -maxdepth 1 -name '*.csv' | wc -l)"
echo "OK: $count CSV-файлов в $data_dir"
SCRIPT
chmod 755 /opt/lab-files/bin/report.sh

for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
    printf 'date,orders,revenue\n2026-%s-01,%d,%d\n' "$m" $((100 + 10#$m * 7)) $((5000 + 10#$m * 350)) > "/opt/lab-files/data/sales-2026-$m.csv"
done

# Поломка 1: повторённый ключ — последняя строка DATA_DIR побеждает и указывает в никуда.
# Поломка 2: концы строк Windows — в значении остаётся невидимый символ \r.
printf '# Настройки отчёта\nDATA_DIR=/opt/lab-files/data\nREPORT_TITLE=Продажи 2026\n\n# временно, для теста\nDATA_DIR=/tmp/lab-files-old\n' \
    | sed 's/$/\r/' > /opt/lab-files/conf/app.conf

# Поломка 3: данные «убрали в архив».
mkdir -p /opt/lab-files/archive/2026-11
mv /opt/lab-files/data /opt/lab-files/archive/2026-11/data

break_done real.linux-files-fix
echo "Запустите отчёт и посмотрите, что он скажет: /opt/lab-files/bin/report.sh"
