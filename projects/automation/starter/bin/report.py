#!/usr/bin/env python3
"""Ежедневный отчёт о сервере в Markdown: бэкапы, последние проверки, диск.

Пишет REPORT_DIR/report-ГГГГ-ММ-ДД.md и печатает путь к нему.
В начале отчёта строка «Статус: OK» или «Статус: ВНИМАНИЕ» с причинами:
  • нет ни одного бэкапа или самый новый старше 26 часов;
  • health.json нет, он старше 30 минут или в нём есть неуспешные проверки.

Только стандартная библиотека.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import shutil
import sys
import time
from dataclasses import dataclass

BACKUP_MAX_AGE_HOURS = 26
HEALTH_MAX_AGE_MINUTES = 30


@dataclass
class BackupSummary:
    count: int
    newest: str | None          # имя самого нового архива или None
    newest_age_hours: float | None
    total_bytes: int


def backups_summary(backup_dir: str, now: float) -> BackupSummary:
    """Сводка по архивам backup-*.tar.gz в backup_dir (возраст — по времени изменения файла).

    Нет каталога или архивов — count=0, newest=None.
    """
    # TODO
    raise NotImplementedError


def load_health(state_dir: str) -> dict | None:
    """Содержимое state_dir/health.json или None, если файла нет или он не читается как JSON."""
    # TODO
    raise NotImplementedError


def problems(summary: BackupSummary, health: dict | None, health_age_minutes: float | None) -> list[str]:
    """Список причин для «ВНИМАНИЕ» на русском; пустой — всё в порядке.

    Неуспешные проверки из health.json перечислить по имени.
    """
    # TODO
    raise NotImplementedError


def render(summary: BackupSummary, health: dict | None, issues: list[str], disk_percent: int, now: float) -> str:
    """Текст отчёта в Markdown: заголовок с датой, статус, причины, раздел про бэкапы, проверки, диск."""
    # TODO
    raise NotImplementedError


def main(env: dict[str, str] | None = None) -> int:
    env = dict(os.environ) if env is None else env
    backup_dir = env.get("BACKUP_DIR", "/var/backups/server-automation")
    state_dir = env.get("STATE_DIR", "/var/lib/server-automation")
    report_dir = env.get("REPORT_DIR", os.path.join(state_dir, "reports"))
    now = time.time()

    summary = backups_summary(backup_dir, now)
    health = load_health(state_dir)
    health_path = os.path.join(state_dir, "health.json")
    health_age = (now - os.path.getmtime(health_path)) / 60 if os.path.exists(health_path) else None
    usage = shutil.disk_usage("/")
    disk_percent = round(usage.used * 100 / usage.total)

    text = render(summary, health, problems(summary, health, health_age), disk_percent, now)
    os.makedirs(report_dir, exist_ok=True)
    path = os.path.join(report_dir, f"report-{dt.date.fromtimestamp(now).isoformat()}.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
