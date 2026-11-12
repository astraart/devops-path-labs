# Проект 1. Автоматизация сервера

Проект после модулей Bash и Python. Результат — ваш репозиторий `server-automation`: скрипты бэкапа, ротации, проверок и ежедневного отчёта, которые работают на сервере по таймерам systemd, с тестами и README.

Рубрика самооценки и типовые замечания ревьюера — в приложении DevOps Path, на экране проекта.

## Что должно работать

1. `bin/backup.sh` архивирует пути из `BACKUP_SOURCES` в `BACKUP_DIR`: имя с датой, проверка архива, файл `.sha256`, права только для владельца. При ошибке — код выхода не 0 и никаких недописанных архивов.
2. `bin/rotate.sh` оставляет `KEEP` последних архивов вместе с их `.sha256` и не трогает чужие файлы. Неверный `KEEP` — код 2, ничего не удалено.
3. `bin/healthcheck.py` проверяет адреса из `HEALTH_URLS` с таймаутом и заполненность диска, пишет `health.json` атомарно, код выхода 1 при любой неудаче.
4. `bin/report.py` раз в сутки пишет отчёт в Markdown со статусом «OK» или «ВНИМАНИЕ» и причинами.
5. Таймеры systemd: бэкап раз в сутки, проверки каждые 5 минут, отчёт раз в сутки. Юниты ограничены: файловая система только для чтения, кроме своих каталогов.
6. Тесты из заготовки проходят, и есть ваши тесты на ошибочные случаи.
7. README объясняет установку, настройку, восстановление из бэкапа и ограничения проекта.

## Как начать

На учебной машине (Ubuntu 24.04):

```bash
sudo apt install -y python3-pytest shellcheck
```

```bash
cp -r ~/devops-path-labs/projects/automation/starter ~/server-automation
```

```bash
cd ~/server-automation && git init -b main && git add . && git commit -m "Заготовка проекта"
```

```bash
python3 -m pytest -q
```

Сначала все тесты падают — это задание. Заполните места с `TODO` в `bin/`, пока тесты не пройдут, затем допишите свои.

## Договорённости

| Что | Где |
|---|---|
| скрипты на сервере | `/opt/server-automation/bin` |
| конфиг сервера | `/etc/server-automation/config.env` (в git — только `config.env.example`) |
| архивы | `/var/backups/server-automation` |
| результат проверок и отчёты | `/var/lib/server-automation`, `/var/lib/server-automation/reports` |
| юниты | `server-automation-{backup,health,report}.{service,timer}` |

Установка на сервер — `sudo ./install.sh`. Повторный запуск безопасен: обновляет скрипты и юниты, но не трогает настроенный конфиг.

## Проверка

```bash
cd ~/devops-path-labs && sudo ./projects/automation/check.sh ЧИСЛО ~/server-automation
```

ЧИСЛО — четыре цифры с экрана проекта в приложении. Скрипт только читает репозиторий и состояние сервера и печатает код для приложения. `sudo` нужен, чтобы прочитать архивы и отчёты — они доступны только root.

## Как удалить с сервера

Архивы и отчёты при этом остаются.

```bash
sudo systemctl disable --now server-automation-backup.timer server-automation-health.timer server-automation-report.timer
```

```bash
sudo rm /etc/systemd/system/server-automation-*.service /etc/systemd/system/server-automation-*.timer
```

```bash
sudo rm -r /opt/server-automation && sudo systemctl daemon-reload
```
