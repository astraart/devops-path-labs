#!/usr/bin/env python3
"""Проверки сервера: адреса из HEALTH_URLS и заполненность корневого диска.

На каждую проверку — строка в stdout: «OK   имя: подробности» или «FAIL имя: подробности».
Итог записывается в STATE_DIR/health.json, его читает отчёт (report.py).
Код выхода: 0 — все проверки прошли, 1 — хотя бы одна не прошла.

Только стандартная библиотека: скрипт работает на чистой Ubuntu без pip и venv.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass


@dataclass
class Result:
    name: str
    ok: bool
    detail: str


def check_url(url: str, timeout: float) -> Result:
    """GET url не дольше timeout секунд.

    name — сам адрес. Успех — итоговый ответ 2xx (переходы по 3xx urllib делает сам), detail — «HTTP 200».
    Ответ 4xx/5xx — неуспех с кодом в detail. Отказ соединения, таймаут, ошибка DNS —
    неуспех с причиной в detail. Исключения наружу не выпускать.
    """
    # TODO
    raise NotImplementedError


def check_disk(path: str, max_percent: int, usage=shutil.disk_usage) -> Result:
    """Занято не больше max_percent процентов диска, на котором лежит path.

    usage — функция с ответом как у shutil.disk_usage (total, used, free); в тестах её подменяют.
    name — «disk {path}», detail — например «занято 42%».
    """
    # TODO
    raise NotImplementedError


def write_state(state_dir: str, results: list[Result], now: float) -> str:
    """Записать state_dir/health.json и вернуть путь к нему.

    Формат: {"checked_at": "2026-11-12T07:00:00+00:00", "ok": true, "results": [{"name", "ok", "detail"}]}
    Запись атомарная: во временный файл в том же каталоге, затем os.replace —
    report.py никогда не прочитает наполовину записанный файл.
    """
    # TODO
    raise NotImplementedError


def main(env: dict[str, str] | None = None) -> int:
    env = dict(os.environ) if env is None else env
    urls = env.get("HEALTH_URLS", "").split()
    timeout = float(env.get("HEALTH_TIMEOUT", "5"))
    max_disk = int(env.get("DISK_MAX_PERCENT", "90"))
    state_dir = env.get("STATE_DIR", "/var/lib/server-automation")

    results = [check_url(u, timeout) for u in urls] + [check_disk("/", max_disk)]
    for r in results:
        print(f"{'OK  ' if r.ok else 'FAIL'} {r.name}: {r.detail}")
    write_state(state_dir, results, time.time())
    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
